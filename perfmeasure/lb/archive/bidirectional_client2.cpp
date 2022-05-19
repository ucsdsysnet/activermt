// bidirectional_client.c
// Send message, await response, wait, loop.

#include <iostream>
#include <cstdio>
#include <cerrno>
#include <cstdint>
#include <ctime>
#include <cstdlib>
#include <cstring>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/select.h>
#include <netinet/in.h>
#include <netdb.h>
#include <sys/ioctl.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <unistd.h>
#include <sstream>
#include <vector>
#include <random>
#include <fstream>

#define __STDC_FORMAT_MACROS 1
#include <cinttypes>

#define SEND_STAT 1
#define RECV_STAT 2
#define MSGBUF_SIZE 64000
#define NSEC_PER_SEC 1000000000
#define DATABUF_ROUNDS 100000

#ifdef DEBUG
#define DEBUGPRINT(x) do { std::cerr << x << std::endl; } while (0)
#else
#define DEBUGPRINT(X)
#endif

const int usec_to_sec = 1000000;
const int nsec_to_usec = 1000;

// Print usage help.
void print_usage(char *progname) {
  fprintf(stderr, "Usage: $> %s <server> <port> <output_tag> <flowDistFilename> <totalTime|-1> <sleepAvg> <sleepStdev> [<sndbuf>]\n",
    progname);
}

void adjustTspec(struct timespec *ts) {
  if (ts->tv_sec < 0) {
    ts->tv_sec = 0;
  }
  if (ts->tv_nsec < 0) {
    ts->tv_nsec = 0;
  }
  if (ts->tv_nsec > 999999999) {
    ts->tv_nsec = 999999999;
  }
  if (ts->tv_sec > 20) {
    ts->tv_sec = 10; // XXX HAX Max 10 second sleep.
  }
}

int doSleep(int64_t sleepTimeNsec) {
  if (sleepTimeNsec < 0) {
    sleepTimeNsec = 0;
  }

  int ret;
  struct timespec req, rem;
  auto seconds = sleepTimeNsec / 1000000000L;
  auto nsec = sleepTimeNsec - (seconds * 1000000000L);
  //auto usec = sleepTimeNsec / 1000;
  req.tv_sec = static_cast<time_t>(seconds);
  req.tv_nsec = static_cast<long>(nsec);
  //if (usec < 0) {
  //  usec = 0;
  //}
  //usleep(static_cast<useconds_t>(usec));
  //return 0;
#if 1
  do {
    adjustTspec(&req);
    ret = nanosleep(&req, &rem);
    if (ret == -1) {
      if (errno == EINTR) {
        req.tv_sec = rem.tv_sec;
        req.tv_nsec = rem.tv_nsec;
        continue;
      } else if (errno == EFAULT) {
        //printf("# Sleep error: EFAULT.\n");
        break;
      } else if (errno == EINVAL) {
        //printf("# Sleep error: EINVAL.\n");
        break;
      } else {
        //printf("# Sleep error: %d.\n", errno);
        break;
      }
    }
  }
  while(ret != 0);
  return ret;
#endif
}

std::vector<int> getDistFromFile(const std::string& filename) {
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

// Set a socket or file descriptor to be non blocking.
// http://www.kegel.com/dkftpbench/nonblocking.html
int setNonblocking(int fd)
{
    int flags;
    /* If they have O_NONBLOCK, use the Posix way to do it */
#if defined(O_NONBLOCK)
    /* Fixme: O_NONBLOCK is defined but broken on SunOS 4.1.x and AIX 3.2.5. */
    if (-1 == (flags = fcntl(fd, F_GETFL, 0)))
        flags = 0;
    return fcntl(fd, F_SETFL, flags | O_NONBLOCK);
#else
    /* Otherwise, use the old way of doing it */
    flags = 1;
    return ioctl(fd, FIONBIO, &flags);
#endif
}

// Create a connected nonblocking socket.
int get_connection(
    const std::string& hostname,
    uint16_t port,
    int *ret,
    struct sockaddr_in *serv_addr) {
  int sockfd, err;
  struct hostent *server;

  sockfd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if (sockfd < 0) {
    *ret = errno;
    return -1;
  }
  int disable = 1;
  if (setsockopt(sockfd, SOL_SOCKET, SO_NO_CHECK, (void*)&disable, sizeof(disable)) < 0) {
      perror("setsockopt failed");
  }

  err = setNonblocking(sockfd);
  if (err) {
    *ret = errno;
    return -1;
  }
  server = gethostbyname(hostname.c_str());
  if (server == NULL) {
      fprintf(stderr,"ERROR, no such host\n");
      *ret = EINVAL;
      return -1;
  }
  memset(serv_addr, 0, sizeof(*serv_addr));
  serv_addr->sin_family = AF_INET;

  memcpy(&serv_addr->sin_addr.s_addr, server->h_addr, server->h_length);
  serv_addr->sin_port = htons(port);

  err = connect(sockfd, (const struct sockaddr *)serv_addr, sizeof(*serv_addr));
  if (connect < 0) {
    *ret = errno;
    return -1;
  }

  // Connect worked.
  *ret = 0;
  return sockfd;
}

// Convert timespec to nanoseconds.
uint64_t linear_nsec_time(struct timespec *time) {
  return time->tv_sec * NSEC_PER_SEC + time->tv_nsec;
}

// Get delta in nanoseconds from two timespecs.
uint64_t calc_delta(struct timespec *start, struct timespec *end) {
  return linear_nsec_time(end) - linear_nsec_time(start);
}
// Wait till socket is readable.
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

// Wait till socket is writeable.
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

// Call read on a socket or file descriptor that uses select to block until
// readable (useful if socket is set to non blocking). Attempt to read the
// specified number of bytes (bufsiz); return number of bytes actually read on
// success or an error.
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
      //printf("# Error clock_gettime_wait_start read: %d\n", *ret);
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
      //printf("# Error clock_gettime_io_start read: %d\n", *ret);
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
        //printf("Error during recv: %d\n", *ret);
        return -1;
      }
    }

    err = clock_gettime(CLOCK_REALTIME, &io_end);
    if (err) {
      *ret = errno;
      //printf("# Error clock_gettime_io_end read: %d\n", *ret);
      return -1;
    }

    if (recv_ret == 0) { // Socket shutdown unexpectedly.
      *ret = ECONNABORTED;
      //printf("# Socket shutdown unexpectedly.\n");
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
      //printf("# Error clock_gettime_wait_start: %d\n", *ret);
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
      //printf("# Error clock_gettime_send_start: %d\n", *ret);
      return -1;
    }

    sent_ret = send(sock, sendbuf, remaining, 0);
    if (sent_ret == -1) {
      if (errno == EAGAIN || errno == EWOULDBLOCK) {
        // We're fine, just continue.
      }
      else {
        *ret = errno;
        //printf("# Error send(): %d\n", *ret);
        return -1;
      }
    }

    err = clock_gettime(CLOCK_REALTIME, &send_end);
    if (err) {
      *ret = errno;
      // printf("# Error clock_gettime_send_end: %d\n", *ret);
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

// Get command line arguments.
int get_args(std::string& hostname, uint16_t *port, std::string& tag,
    std::string& flowDistFilename, long int *totalTime,
    long int *sleepAvg, long int *sleepStdev, int *sndbuf, int *tos,
    int argc, char **argv) {
  int port_temp;
  if (argc < 8) {
    print_usage(argv[0]);
    return EINVAL;
  }

  hostname = std::string(argv[1]);
  port_temp = atoi(argv[2]);
  *port = port_temp;
  tag = std::string(argv[3]);
  flowDistFilename = std::string(argv[4]);
  *totalTime = atol(argv[5]);
  *sleepAvg = atol(argv[6]);
  *sleepStdev = atol(argv[7]);
  *sndbuf = argc > 8 ? atoi(argv[8]) : 0;
  *tos = argc > 9 ? atoi(argv[9]) : 0;

  // Unsafe, should fix.
  return 0;
}

std::string build_header(struct sockaddr_in *serv_addr, int sock, int *ret) {
  std::stringstream ss;
  const char *strret;
  char sip[INET_ADDRSTRLEN];
  char dip[INET_ADDRSTRLEN];
  struct sockaddr_in client_addr;
  socklen_t sock_siz = sizeof(client_addr);

  // We want to print out connection details so we can associate with error.
  // Get the sip, dip, sport, dport, ipType and proto.
  if (getsockname(sock, (struct sockaddr *) &client_addr, &sock_siz)  == -1) {
    *ret = errno;
    perror("getsockname");
    return "";
  }
  // Alright, this gives us local IP and port number.
  // We already have the server addr from the connect() call.

  // Get the source IP.
  strret = inet_ntop(AF_INET, &client_addr.sin_addr, sip, sizeof(sip));
  if (!strret) {
    *ret = errno;
    perror("inet_ntop");
    return "";
  }
  // Get the dest IP.
  strret = inet_ntop(AF_INET, &serv_addr->sin_addr, dip, sizeof(dip));
  if (!strret) {
    *ret = errno;
    perror("inet_ntop");
    return "";
  }
  // Print header formatted string.
  *ret = 0;
  ss << "sip=" << sip
    << ",dip=" << dip
    << ",sport=" << ntohs(client_addr.sin_port)
    << ",dport=" << ntohs(serv_addr->sin_port);
  return ss.str();
}

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
    const std::string& headerbuf,
    const std::string& tag,
    uint64_t roundnum,
    bool full,
    int sock
  ) {
  uint64_t limit = full ? DATABUF_ROUNDS : roundnum % DATABUF_ROUNDS;
  for (uint64_t bufIdx = 0; bufIdx < limit; ++bufIdx) {
    printf(
      "%s,%" PRIu64 ",tx,%" PRIu64 ",timestamp,%" PRIu64 ",bytesSent,%" PRIu64 ",sockfd=%d,tgid=%d,%s,%s\n",
      sendOrRecvStat[bufIdx] == SEND_STAT ? "wait" : "recvwait",
      resultsWait[bufIdx], resultsIo[bufIdx], timestamps[bufIdx],
      bytesXferPerRound[bufIdx], sock, getpid(), headerbuf.c_str(), tag.c_str()
    );
  }
  output_snd_sockbuf_stats(sock);
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
    const std::string& headerbuf,
    const std::string& tag,
    std::vector<char>& msgbuf
    ) {
  int ret = 0;
  uint64_t ioTime = 0, waitTime = 0, timestamp = 0, bytesXfer = 0;
  DEBUGPRINT("Sending message of size " << msgLen);
  // First send the header (payload size).
  if (do_send((const char *) &msgLen, sizeof(msgLen), sock, &ret,
        &waitTime, &ioTime, &timestamp, &bytesXfer ) == -1) {
    //printf("# Sending header failed: %d.\n", ret);
    return ret;
  }
  DEBUGPRINT("Sending payload.");
  //memset(&msgbuf[0], 1000, MSGBUF_SIZE);
  // Alright, now we send the payload of the response.
  for (auto remaining = msgLen; remaining > 0; ) {
    // This is a read-send loop. Before we do a send (for which we record
    // stats) make sure there is room to record stats, else flush.
    if (roundnum > 0 && roundnum % DATABUF_ROUNDS == 0) {
      print_buffered_stats(
        sendOrRecvStat, resultsWait, resultsIo, timestamps, bytesXferPerRound,
        headerbuf.c_str(), tag, roundnum, true, sock
      );
    }

    auto xferThisRound = remaining > MSGBUF_SIZE ? MSGBUF_SIZE : remaining;
    if (do_send(
          &msgbuf[0], xferThisRound, sock, &ret,
          &waitTime, &ioTime, &timestamp, &bytesXfer) == -1) {
      //printf("# Sending payload failed: %d\n", ret);
      return ret;
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

int read_msg_over_sock(
    int sock,
    uint64_t& roundnum,
    std::vector<uint8_t>& sendOrRecvStat,
    std::vector<uint64_t>& resultsWait,
    std::vector<uint64_t>& resultsIo,
    std::vector<uint64_t>& timestamps,
    std::vector<uint64_t>& bytesXferPerRound,
    const std::string& headerbuf,
    const std::string& tag,
    std::vector<char>& msgbuf
    ) {
  // Get size of response.
  int ret = 0;
  uint64_t responseSize = 0, ioTime = 0, waitTime = 0, timestamp = 0, bytesXfer = 0;
  DEBUGPRINT("Getting response size.");
  auto err = do_recv((char *)&responseSize, sizeof(responseSize), sock, &ret,
    &waitTime, &ioTime, &timestamp, &bytesXfer);
  DEBUGPRINT("header do_recv returned: " << err << " and ret: " << ret);
  if (err == -1) {
    //printf("# Reading header failed: %d.\n", ret);
    return ret;
  }

  DEBUGPRINT("Got response size " << responseSize << ", reading payload.");
  // Alright, now we read the payload of the response.
  for (auto remaining = responseSize; remaining > 0; ) {
    // This is a read-send loop. Before we do a send (for which we record
    // stats) make sure there is room to record stats, else flush.
    if (roundnum > 0 && roundnum % DATABUF_ROUNDS == 0) {
      print_buffered_stats(
        sendOrRecvStat, resultsWait, resultsIo, timestamps, bytesXferPerRound,
        headerbuf, tag, roundnum, true, sock
      );
    }

    auto rcvThisRound = remaining > MSGBUF_SIZE ? MSGBUF_SIZE : remaining;
    if (do_recv(
          &msgbuf[0], rcvThisRound, sock, &ret,
          &waitTime, &ioTime, &timestamp, &bytesXfer) == -1) {
      //printf("# Reading payload failed: %d.\n", ret);
      return ret;
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

int shouldQuit(time_t endTime) {
  // If endTime is set (>= 0) and we're past it, quit.
  if (endTime >= 0 && time(NULL) >= endTime) {
    return 1;
  }
  // Else, continue.
  return 0;
}

int do_send_loop(
    const std::string& hostname,
    uint16_t port,
    const std::string& tag,
    long int totalTime,
    long int sleepAvgNsec,
    long int sleepStdevNsec,
    const std::string& flowDistFile,
    int sndbuf,
    int tos) {
  int ret = 0, sock = -1;
  uint64_t roundnum = 0;
  struct sockaddr_in serv_addr;
  std::string headerstr;
  time_t endTime;

  // Set up flowdist and RNGs.
  // Cribbed from http://en.cppreference.com/w/cpp/numeric/random/normal_distribution
  std::random_device rd;
  std::mt19937 gen(rd());
  std::normal_distribution<long double> sleepDist(
    static_cast<long double>(sleepAvgNsec),
    static_cast<long double>(sleepStdevNsec)
  );
  std::vector<int> flowSizeBytesList = getDistFromFile(flowDistFile);
  std::uniform_int_distribution<> flowIdxDist(0, flowSizeBytesList.size() - 1);
  // Allocate buffers.
  std::vector<char> msgbuf(MSGBUF_SIZE);
  std::vector<uint64_t> resultsWait(DATABUF_ROUNDS);
  std::vector<uint64_t> resultsIo(DATABUF_ROUNDS);
  std::vector<uint64_t> timestamps(DATABUF_ROUNDS);
  std::vector<uint64_t> bytesXferPerRound(DATABUF_ROUNDS);
  std::vector<uint8_t> sendOrRecvStat(DATABUF_ROUNDS);

  // Set up socket.
  sock = get_connection(hostname, port, &ret, &serv_addr, tos);
  if (sock == -1) {
    goto out;
  }
  if (sndbuf > 0) {
    setsockopt(sock, SOL_SOCKET, SO_SNDBUF, &sndbuf, sizeof(sndbuf));
  }
  // Get header string.
  headerstr = "foobar";
  headerstr = build_header(&serv_addr, sock, &ret);
  if (ret == -1) {
    goto closesock;
  }

  // Calculate end time.
  endTime = totalTime >= 0 ? time(NULL) + ((int)totalTime) : -1;
  // Loop: read message from stdin, then send it. Repeat till stdin closes.
  for (;;) {
    // Check if we're due to quit.
    if (shouldQuit(endTime)) {
      //printf("# Should quit evaluated true.\n");
      break;
    }
    // Sleep if needed.
    if (sleepAvgNsec != 0 && sleepStdevNsec != 0) {
      auto sleepTimeNsec = std::round(sleepDist(gen));
      ret = doSleep(static_cast<int64_t>(sleepTimeNsec));
      if (ret < 0) {
        //printf("# Unable to sleep.\n");
        break;
      }
    }
    // Send bytes.
    long bytesToSend = flowSizeBytesList[flowIdxDist(gen)];
    DEBUGPRINT("Sending " << bytesToSend << " bytes message.");
    ret = send_msg_over_sock(
      bytesToSend, sock, roundnum,
      sendOrRecvStat, resultsWait, resultsIo, timestamps, bytesXferPerRound,
      headerstr.c_str(), tag, msgbuf);
    if (ret == -1) {
      //printf("# Unable to send message.\n");
      break;
    }

    DEBUGPRINT("Getting response.");
    // Get response from server.
    ret = read_msg_over_sock(
      sock, roundnum,
      sendOrRecvStat, resultsWait, resultsIo, timestamps, bytesXferPerRound,
      headerstr.c_str(), tag, msgbuf);
    if (ret == -1) {
      //printf("# Unable to receive response.\n");
      break;
    }
    DEBUGPRINT("Continuing.");
  }
  // Print out details for remainder of stats.
  print_buffered_stats(
    sendOrRecvStat, resultsWait, resultsIo, timestamps, bytesXferPerRound,
    headerstr.c_str(), tag, roundnum, false, sock);

closesock:
  close(sock);
out:
  return ret;
}

int main(int argc, char **argv) {
  int ret;
  long int totalTime, sleepAvgNsec, sleepStdevNsec;
  std::string hostname, tag, flowDistFile;
  uint16_t port;
  int sndbuf;
  int tos;
  ret = get_args(hostname, &port, tag, flowDistFile, &totalTime,
    &sleepAvgNsec, &sleepStdevNsec, &sndbuf, &tos, argc, argv);
  if (ret) {
    exit(1);
  }
  printf("#startclient\n");
  return do_send_loop(hostname, port, tag, totalTime, sleepAvgNsec,
    sleepStdevNsec, flowDistFile, sndbuf, tos);
}
