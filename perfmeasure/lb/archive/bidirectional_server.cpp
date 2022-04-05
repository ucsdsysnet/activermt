#include <ios>
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <thread>
#include <cstdio>
#include <cstring>
#include <sstream>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <mutex>
#include <boost/iostreams/filter/gzip.hpp>
#include <boost/iostreams/filtering_streambuf.hpp>
#include <random>
#include <vector>

#define __STDC_FORMAT_MACROS 1
#include <cinttypes>

#define SEND_STAT 1
#define RECV_STAT 2
#define SEC_TO_NSEC 1000000000
#define MSGBUF_SIZE 64000
#define DATABUF_ROUNDS 100000
#define NSEC_PER_SEC 1000000000

#ifdef DEBUG
#define DEBUGPRINT(x) do { std::cerr << x << std::endl; } while (0)
#else
#define DEBUGPRINT(X)
#endif

using std::ios_base;
using std::cerr;
using std::cout;
using std::endl;
using std::string;
using std::ofstream;
using std::stringstream;
using std::ostream;
using boost::iostreams::filtering_streambuf;
using boost::iostreams::gzip_compressor;
using boost::iostreams::output;
using std::mutex;

namespace faultfinder {

void output_snd_sockbuf_stats(int sock) {
  // Get time and sockbuf size.
  int sendbuf_size = 0;
  socklen_t optsize = sizeof(sendbuf_size);
  auto now = time(NULL);
  auto err = getsockopt(sock, SOL_SOCKET, SO_SNDBUF, &sendbuf_size,
    &optsize);
  if (err == -1) {
    perror("error_getsockopt");
    printf("error=getsockopt,%d\n", err);
    return;
  }
  printf("datatype=sendbuf_size,timestamp=%ld,sendbuf=%d\n", now, sendbuf_size);
}

void print_buffered_stats(
    const std::vector<uint8_t>& sendOrRecvStat,
    const std::vector<uint64_t>& resultsWait,
    const std::vector<uint64_t>& resultsIo,
    const std::vector<uint64_t>& timestamps,
    const std::vector<uint64_t>& bytesXferPerRound,
    const char *headerbuf,
    const char *tag,
    uint64_t roundnum,
    bool full,
    std::mutex& lock,
    int sock
  ) {
  uint64_t limit = full ? DATABUF_ROUNDS : roundnum % DATABUF_ROUNDS;
  lock.lock();
  for (uint64_t bufIdx = 0; bufIdx < limit; ++bufIdx) {
    printf(
      "%s,%" PRIu64 ",tx,%" PRIu64 ",timestamp,%" PRIu64 ",bytesSent,%" PRIu64 ",sockfd=%d,tgid=%d,%s,%s\n",
      sendOrRecvStat[bufIdx] == SEND_STAT ? "wait" : "recvwait",
      resultsWait[bufIdx], resultsIo[bufIdx], timestamps[bufIdx],
      bytesXferPerRound[bufIdx], sock, getpid(), headerbuf, tag
    );
  }
  output_snd_sockbuf_stats(sock);
  lock.unlock();
}

std::vector<int> getDistFromFile(const char *filename) {
  std::vector<int> dist;
  std::ifstream ifs(filename, std::ifstream::in);
  char buf[256];

  while (!ifs.eof()) {
    ifs.getline(buf, sizeof(buf));
    if (buf[0] == '#') {
      continue;
    }
    if (buf[0] == '\n') {
      continue;
    }
    auto size = atoi(buf);
    if (size <= 0) {
      continue;
    }
    dist.push_back(size);
  }
  ifs.close();
  return dist;
}

uint64_t linear_nsec_time(struct timespec *time) {
  return time->tv_sec * NSEC_PER_SEC + time->tv_nsec;
}

uint64_t calc_delta(struct timespec *start, struct timespec *end) {
  return linear_nsec_time(end) - linear_nsec_time(start);
}

int waitWriteable(int sock, fd_set *sockset, int *err) {
  int ret;
  struct timeval tv;
  FD_ZERO(sockset);
  FD_SET(sock, sockset);

  tv.tv_sec = 5;
  tv.tv_usec = 0;

  ret = select(sock + 1, NULL, sockset, NULL, &tv);
  if (ret == -1) {
    *err = errno;
    return -1;
  }
  *err = 0;
  return ret;
}

int waitReadable(int sock, fd_set *sockset, int *err) {
  int ret;
  struct timeval tv;
  FD_ZERO(sockset);
  FD_SET(sock, sockset);

  tv.tv_sec = 5;
  tv.tv_usec = 0;

  ret = select(sock + 1, sockset, NULL, NULL, &tv);
  if (ret == -1) {
    *err = errno;
    return -1;
  }
  *err = 0;
  return ret;
}

ssize_t readUntilBytes(int fd, char *buf, int bufsiz, int *ret) {
  int selRet, err, remaining = bufsiz;
  ssize_t recv_ret, bytes_read = 0;
  fd_set read_sockset;

  while (remaining > 0) {
    // Block till we're ready.
    FD_ZERO(&read_sockset);
    FD_SET(fd, &read_sockset);
    selRet = select(fd + 1, &read_sockset, NULL, NULL, NULL);
    if (selRet == -1) {
      *ret = errno;
      return -1;
    }
    // Not ready? Continue.
    if (selRet == 0) {
      continue;
    }
    // Ready, attempt to read.
    recv_ret = read(fd, buf + bytes_read, remaining);
    if (recv_ret == -1) {
      err = errno;
      // If it's not ready, continue, else return error.
      if (err == EAGAIN || err == EWOULDBLOCK) {
        continue;
      } else {
        *ret = err;
        return -1;
      }
    }
    if (recv_ret == 0) {
      if (bytes_read == 0) {
        // Orderly end of file, not in the middle of a message.
        *ret = 0;
        return -1;
      } else {
        // Unexpected EOF.
        *ret = ECONNABORTED;
        return -1;
      }
    }
    // Alright, read some bytes.
    remaining -= recv_ret;
    bytes_read += recv_ret;
  }
  // Done.
  *ret = 0;
  return bytes_read;
}

int do_recv(
    char *recvbuf,
    int toRecv,
    int sock,
    int *ret,
    uint64_t *waitDelta,
    uint64_t *rxDelta,
    uint64_t *timestamp,
    uint64_t *bytesRcvd) {
  int remaining = toRecv, err = 0, sockReady = 0;
  ssize_t recv_ret;
  struct timespec wait_start, io_start, io_end;
  fd_set sockset;

  *bytesRcvd = 0;
  *waitDelta = 0;
  *rxDelta = 0;

  while (remaining > 0) {
    err = clock_gettime(CLOCK_REALTIME, &wait_start);
    if (err) {
      *ret = errno;
      //printf("# Error gettime recv wait_start: %d\n", *ret);
      return -1;
    }

poll:
    // We select and wait until the socket is writable before we send.
    sockReady = waitReadable(sock, &sockset, &err);
    if (!sockReady) {
      goto poll;
    }
    // Alright, sock is ready.
    err = clock_gettime(CLOCK_REALTIME, &io_start);
    if (err) {
      *ret = errno;
      //printf("# Error gettime recv io_start: %d\n", *ret);
      return -1;
    }

    // Attempt to receive up to the total remaining size.
    recv_ret = recv(sock, recvbuf, remaining, 0);
    if (recv_ret == -1) {
      if (errno == EAGAIN || errno == EWOULDBLOCK) {
        // We're fine, just continue.
      }
      else {
        *ret = errno;
        //printf("# Error recv: %d\n", *ret);
        return -1;
      }
    }

    err = clock_gettime(CLOCK_REALTIME, &io_end);
    if (err) {
      *ret = errno;
      //printf("# Error gettime recv io_end: %d\n", *ret);
      return -1;
    }

    if (recv_ret == 0) { // Socket shutdown unexpectedly.
      *ret = ECONNABORTED;
      //printf("# Error do_recv: unexpected sock shutdown.\n");
      return -1;
    }
    if (recv_ret > 0) {
      remaining -= recv_ret;
      *bytesRcvd += recv_ret;
    }
    *waitDelta += calc_delta(&wait_start, &io_start);
    *rxDelta += calc_delta(&io_start, &io_end);
  }

  // Return timestamp as being the last io_end.
  *timestamp = linear_nsec_time(&io_end);
  return 0;
}

int do_send(
    const char *sendbuf,
    int toSend,
    int sock,
    int *ret,
    uint64_t *waitDelta,
    uint64_t *txDelta,
    uint64_t *timestamp,
    uint64_t *bytesSent) {
  int remaining = toSend, err = 0, sockReady = 0;
  ssize_t sent_ret;
  struct timespec wait_start, send_start, send_end;
  fd_set sockset;

  *bytesSent = 0;
  *waitDelta = 0;
  *txDelta = 0;

  while (remaining > 0) {
    err = clock_gettime(CLOCK_REALTIME, &wait_start);
    if (err) {
      *ret = errno;
      //printf("# Error gettime send wait_start: %d\n", *ret);
      return -1;
    }

poll:
    // We select and wait until the socket is writable before we send.
    sockReady = waitWriteable(sock, &sockset, &err);
    if (!sockReady) {
      goto poll;
    }
    // Alright, sock is ready.
    err = clock_gettime(CLOCK_REALTIME, &send_start);
    if (err) {
      *ret = errno;
      //printf("# Error gettime send io_start: %d\n", *ret);
      return -1;
    }

    sent_ret = send(sock, sendbuf, remaining, 0);
    if (sent_ret == -1) {
      if (errno == EAGAIN || errno == EWOULDBLOCK) {
        // We're fine, just continue.
      }
      else {
        *ret = errno;
        //printf("# Error send: %d\n", *ret);
        return -1;
      }
    }

    err = clock_gettime(CLOCK_REALTIME, &send_end);
    if (err) {
      *ret = errno;
      //printf("# Error gettime send io_end: %d\n", *ret);
      return -1;
    }

    if (sent_ret > 0) {
      remaining -= sent_ret;
      *bytesSent += sent_ret;
    }
    *waitDelta += calc_delta(&wait_start, &send_start);
    *txDelta += calc_delta(&send_start, &send_end);
  }

  // Return timestamp as being the last send_end.
  *timestamp = linear_nsec_time(&send_end);
  *ret = 0;
  return 0;
}

class Server {
 public:
  Server(
    const char *portStr,
    int port,
    const char *flowDistFile,
    const char *localTag,
    int sndbuf,
    int tos)
    : portStr_(portStr),
      port_(port),
      flowDistFile_(flowDistFile),
      localTag_(localTag),
      sndbuf_(sndbuf),
      tos_(tos) {
    initializeFlowDist();
    createBindSocket();
  }
  int listenLoop();

 private:
  const char *portStr_;
  int port_;
  const char *flowDistFile_;
  const char *localTag_;
  int sndbuf_;
  int listenSock_;
  int tos_;
  mutex lock_;
  std::random_device rd_;
  std::mt19937 gen_;
  std::vector<int> flowSizeBytesList_;
  std::uniform_int_distribution<> flowIdxDist_;
  char hostIp_[20];

  void connHandler(int remote_sock, struct sockaddr_storage remote_addr);
  void createBindSocket();
  void initializeFlowDist();
  std::string getHeader(const struct sockaddr_storage& remote_addr,
    int remoteSock);

};

void Server::initializeFlowDist() {
  // Cribbed from http://en.cppreference.com/w/cpp/numeric/random/normal_distribution
  gen_.seed(rd_());
  flowSizeBytesList_ = getDistFromFile(flowDistFile_);
  flowIdxDist_ = std::uniform_int_distribution<>(0, flowSizeBytesList_.size() - 1);
}

int Server::listenLoop() {
  while (true) {
    struct sockaddr_storage remote_addr;
    socklen_t addr_size = sizeof(remote_addr);
    int remote_sock = accept4(listenSock_, (struct sockaddr *) &remote_addr,
      &addr_size, SOCK_NONBLOCK);
    // Handle connection in a new thread.
    std::thread connHandlerThread(&Server::connHandler, this, remote_sock,
      remote_addr);
    connHandlerThread.detach();
  }

  return 0;
}

std::string Server::getHeader(const struct sockaddr_storage& remote_addr,
    int remoteSock) {
  char remotehostname[64];
  char remoteport[10];
  socklen_t addrlen = sizeof(remote_addr);

  // Get peer for remote sock.

  getnameinfo((struct sockaddr *) &remote_addr, addrlen,
    remotehostname, sizeof(remotehostname),
    remoteport, sizeof(remoteport),
    NI_NUMERICHOST | NI_NUMERICSERV);
  std::stringstream fkss;
  fkss << "sip=" << localTag_ << ",sport=" << port_;
  fkss << ",dip=" << remotehostname << ",dport=" << remoteport;
  return fkss.str();
}

int read_msg_over_sock(
    int sock,
    uint64_t& roundnum,
    std::vector<uint8_t>& sendOrRecvStat,
    std::vector<uint64_t>& resultsWait,
    std::vector<uint64_t>& resultsIo,
    std::vector<uint64_t>& timestamps,
    std::vector<uint64_t>& bytesXferPerRound,
    const char *headerbuf,
    const char *tag,
    std::vector<char>& msgbuf,
    int *ret,
    std::mutex& lock
    ) {
  // Get size of response.
  DEBUGPRINT("Getting message size.");
  uint64_t responseSize = 0, ioTime = 0, waitTime = 0, timestamp = 0, bytesXfer = 0;
  if (do_recv((char *)&responseSize, sizeof(responseSize), sock, ret,
    &waitTime, &ioTime, &timestamp, &bytesXfer) == -1) {
    //printf("# Error reading header: %d\n", *ret);
    return -1;
  }
  DEBUGPRINT("Got message size " << responseSize << ", reading payload.");
  // Alright, now we read the payload of the response.
  for (auto remaining = responseSize; remaining > 0; ) {
    // This is a read-send loop. Before we do a send (for which we record
    // stats) make sure there is room to record stats, else flush.
    if (roundnum > 0 && roundnum % DATABUF_ROUNDS == 0) {
      print_buffered_stats(
        sendOrRecvStat, resultsWait, resultsIo, timestamps, bytesXferPerRound,
        headerbuf, tag, roundnum, true, lock, sock
      );
    }

    auto rcvThisRound = remaining > MSGBUF_SIZE ? MSGBUF_SIZE : remaining;
    if (do_recv(
          &msgbuf[0], rcvThisRound, sock, ret,
          &waitTime, &ioTime, &timestamp, &bytesXfer) == -1) {
      //printf("# Error reading payload: %d\n", *ret);
      return -1;
    }
    DEBUGPRINT("Bytes read: " << bytesXfer);
    remaining -= bytesXfer;
    // Store stats.
    auto bufIdx = roundnum % DATABUF_ROUNDS;
    resultsWait[bufIdx] = waitTime;
    resultsIo[bufIdx] = ioTime;
    timestamps[bufIdx] = timestamp;
    bytesXferPerRound[bufIdx] = bytesXfer;
    sendOrRecvStat[bufIdx] = RECV_STAT;

    ++roundnum;
  }
  DEBUGPRINT("Got entire payload.");
  // Got entire request, done.
  return 0;
}

int send_msg_over_sock(
    uint64_t msgLen,
    int sock,
    uint64_t& roundnum,
    std::vector<uint8_t>& sendOrRecvStat,
    std::vector<uint64_t>& resultsWait,
    std::vector<uint64_t>& resultsIo,
    std::vector<uint64_t>& timestamps,
    std::vector<uint64_t>& bytesXferPerRound,
    const char *headerbuf,
    const char *tag,
    std::vector<char>& msgbuf,
    int *ret,
    std::mutex& lock
    ) {
  uint64_t ioTime = 0, waitTime = 0, timestamp = 0, bytesXfer = 0;
  DEBUGPRINT("Sending message of size " << msgLen);
  // First send the header (payload size).
  auto err = do_send((const char *) &msgLen, sizeof(msgLen), sock, ret,
        &waitTime, &ioTime, &timestamp, &bytesXfer);
  if (err == -1) {
    //printf("# Error do_send: %d\n", *ret);
    return -1;
  }
  DEBUGPRINT("Sending payload.");
  memset(&msgbuf[0], 1000, MSGBUF_SIZE);
  // Alright, now we send the payload of the response.
  for (auto remaining = msgLen; remaining > 0; ) {
    // This is a read-send loop. Before we do a send (for which we record
    // stats) make sure there is room to record stats, else flush.
    if (roundnum > 0 && roundnum % DATABUF_ROUNDS == 0) {
      // Sender side: we also print out sndbuf size.
      print_buffered_stats(
        sendOrRecvStat, resultsWait, resultsIo, timestamps, bytesXferPerRound,
        headerbuf, tag, roundnum, true, lock, sock
      );
    }

    auto xferThisRound = remaining > MSGBUF_SIZE ? MSGBUF_SIZE : remaining;
    if (do_send(
          &msgbuf[0], xferThisRound, sock, ret,
          &waitTime, &ioTime, &timestamp, &bytesXfer) == -1) {
      //printf("# Error payload do_send: %d\n", *ret);
      return -1;
    }
    remaining -= bytesXfer;
    // Store stats.
    auto bufIdx = roundnum % DATABUF_ROUNDS;
    resultsWait[bufIdx] = waitTime;
    resultsIo[bufIdx] = ioTime;
    timestamps[bufIdx] = timestamp;
    bytesXferPerRound[bufIdx] = bytesXfer;
    sendOrRecvStat[bufIdx] = SEND_STAT;

    // Yield after every send.
    usleep(0);

    // End of sending round.
    ++roundnum;
  }
  // Sent entire message, done.
  DEBUGPRINT("Sent entire payload.");
  return 0;
}

void Server::connHandler(int sock, struct sockaddr_storage remote_addr) {
  uint64_t roundnum = 0;
  int ret = 0, err = 0;

  // Set up send buffer size (disables tcp autotune) if specified.
  if (sndbuf_ > 0) {
    setsockopt(sock, SOL_SOCKET, SO_SNDBUF, &sndbuf_, sizeof(sndbuf_));
  }

  setsockopt(sock, IPPROTO_IP, IP_TOS,  &tos_, sizeof(tos_));

  // Get header and tag strings.
  string headerstr = getHeader(remote_addr, sock);
  const char *tag = "server";

  // Allocate buffers.
  std::vector<char> msgbuf(MSGBUF_SIZE);
  std::vector<uint64_t> resultsWait(DATABUF_ROUNDS);
  std::vector<uint64_t> resultsIo(DATABUF_ROUNDS);
  std::vector<uint64_t> timestamps(DATABUF_ROUNDS);
  std::vector<uint64_t> bytesXferPerRound(DATABUF_ROUNDS);
  std::vector<uint8_t> sendOrRecvStat(DATABUF_ROUNDS);

  while (true) {
    // Read incoming message.
    DEBUGPRINT("Reading incoming message.");
    err = read_msg_over_sock(
      sock, roundnum,
      sendOrRecvStat, resultsWait, resultsIo, timestamps, bytesXferPerRound,
      headerstr.c_str(), tag, msgbuf, &ret, lock_);
    DEBUGPRINT("read_msg_over_sock: returned " << ret);
    if (err == -1) {
      //printf("# Error reading: %d\n", ret);
      break;
    }
    DEBUGPRINT("Read message, picking response size.");
    // Pick a response size.
    auto responseSize = flowSizeBytesList_[flowIdxDist_(gen_)];
    DEBUGPRINT("Sending response of size " << responseSize);
    // Send response.
    err = send_msg_over_sock(
      responseSize, sock, roundnum,
      sendOrRecvStat, resultsWait, resultsIo, timestamps, bytesXferPerRound,
      headerstr.c_str(), tag, msgbuf, &ret, lock_);
    if (ret == -1) {
      //printf("# Error sending: %d\n", ret);
      break;
    }
    DEBUGPRINT("Sent response, continuining.");
  }
  // Print out details for remainder of stats and we're done.
  print_buffered_stats(
    sendOrRecvStat, resultsWait, resultsIo, timestamps, bytesXferPerRound,
    headerstr.c_str(), tag, roundnum, false, lock_, sock);
  close(sock);
}

void Server::createBindSocket() {
  struct addrinfo hints, *res;
  memset(&hints, 0, sizeof(hints));
  hints.ai_family = AF_INET;
  hints.ai_socktype = SOCK_STREAM;
  hints.ai_flags = AI_PASSIVE;
  getaddrinfo(NULL, portStr_, &hints, &res);

  listenSock_ = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
  bind(listenSock_, res->ai_addr, res->ai_addrlen);
  listen(listenSock_, 10);
  inet_ntop(res->ai_family, &((struct sockaddr_in *)&res->ai_addr)->sin_addr, hostIp_, sizeof(hostIp_));
  freeaddrinfo(res);
}

} // endns faultfinder

int main(int argc, char **argv) {
  if (argc < 4) {
    cerr << "Usage: $> " << argv[0] << " <listenPort> <flowdist> <localTag> [<sndbuf>]" << endl;
    exit(1);
  }
  const char *portStr = argv[1];
  int port = atoi(portStr);
  const char *flowDistFile = argv[2];
  const char *localTag = argv[3];
  int sndbuf = argc > 4 ? atoi(argv[4]) : 0;
  int tos = argc > 5 ? atoi(argv[5]) : 0;

  faultfinder::Server server(portStr, port, flowDistFile, localTag, sndbuf, tos);
  printf("#startserver\n");
  return server.listenLoop();
}
