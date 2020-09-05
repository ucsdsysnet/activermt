#include <pd/pd.h>
#include <tofino/pdfixed/pd_conn_mgr.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define PD_DEV_PIPE_ALL 0xffff
#define FLAG_FROM_HW    1

p4_pd_status_t      status;
p4_pd_sess_hdl_t    sess_hdl;
p4_pd_dev_target_t  allpipes_on_dev_0;

int main(int argc, char* argv[]) {

    int ts_result;
    uint64_t elapsed_us;
    struct timespec ts_start, ts_end;
    p4_pd_entry_hdl_t entry_hdl;

    int value_count, num_read;
    p4_pd_active_generated_heap_1_value_t value;
    p4_pd_active_generated_heap_1_value_t values[8192];

    p4_pd_active_generated_memalloc_match_spec_t matchspec;
    
    status = p4_pd_client_init(&sess_hdl);

    if(status != 0) {
        printf("Failed to init client!\n");
        exit(1);
    }

    allpipes_on_dev_0.device_id = 0;
    allpipes_on_dev_0.dev_pipe_id = PD_DEV_PIPE_ALL;

    ts_result = clock_gettime(CLOCK_MONOTONIC, &ts_start);

    /*matchspec.as_fid = 1;
    matchspec.as_flag_reqalloc = 1;
    p4_pd_active_generated_memalloc_table_add_with_request_allocation(
        sess_hdl,
        allpipes_on_dev_0,
        &matchspec,
        &entry_hdl
    );*/

    p4_pd_active_generated_register_read_heap_1(
        sess_hdl,
        allpipes_on_dev_0,
        0,
        REGISTER_READ_HW_SYNC,
        &value,
        &value_count
    );

    /*p4_pd_active_generated_register_range_read_heap_1(
        sess_hdl,
        allpipes_on_dev_0,
        0,
        8192,
        FLAG_FROM_HW,
        &num_read,
        &values[0],
        &value_count
    );*/

    p4_pd_complete_operations(sess_hdl);

    ts_result = clock_gettime(CLOCK_MONOTONIC, &ts_end);

    elapsed_us = ((ts_end.tv_sec - ts_start.tv_sec) * 1E9 + (ts_end.tv_nsec - ts_start.tv_nsec)) / 1E3;
    printf("Elapsed time %lu us\n", elapsed_us);

    printf("value count %d, f0=%d, f1=%d\n", value_count, value.f0, value.f1);

    status = p4_pd_client_cleanup(sess_hdl);

    return 0;
}