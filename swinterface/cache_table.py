clear_all()

p4_pd.forward_table_add_with_setegr(
    p4_pd.forward_match_spec_t(
        ipv4Addr_to_i32("192.168.0.1"),
        32
    ),
    p4_pd.setegr_action_spec_t(188)
)
p4_pd.forward_table_add_with_setegr(
    p4_pd.forward_match_spec_t(
        ipv4Addr_to_i32("192.168.1.1"),
        32
    ),
    p4_pd.setegr_action_spec_t(184)
)

p4_pd.objhashing_table_add_with_hashobj_1(
    p4_pd.objhashing_match_spec_t(
        as_fid=1
    )
)
p4_pd.objhashing_table_add_with_hashobj_2(
    p4_pd.objhashing_match_spec_t(
        as_fid=2
    )
)
p4_pd.objhashing_table_add_with_hashobj_3(
    p4_pd.objhashing_match_spec_t(
        as_fid=3
    )
)
p4_pd.objhashing_table_add_with_hashobj_4(
    p4_pd.objhashing_match_spec_t(
        as_fid=4
    )
)

p4_pd.cachekey_table_add_with_readkey(
    p4_pd.cachekey_match_spec_t(
        as_acc2=0
    )
)

p4_pd.cachekey_table_add_with_writekey(
    p4_pd.cachekey_match_spec_t(
        as_acc2=1
    )
)

p4_pd.cachevalue_table_add_with_readvalue(
    p4_pd.cachevalue_match_spec_t(
        meta_mbr=0,
        as_acc2=0
    )
)

p4_pd.cachevalue_table_add_with_writevalue(
    p4_pd.cachevalue_match_spec_t(
        meta_mbr=0,
        as_acc2=1
    )
)

p4_pd.keyeq_table_add_with_cmpkey(
    p4_pd.keyeq_match_spec_t(
        as_acc2=0
    )
)

p4_pd.cachehitmiss_table_add_with_cachemiss(
    p4_pd.cachehitmiss_match_spec_t(
        as_acc2=0,
        as_acc=0
    )
)

p4_pd.route_table_add_with_rts(
    p4_pd.route_match_spec_t(
        as_acc2=0
    )
)

p4_pd.cmsprep_1_table_add_with_hashcms_1_1(
    p4_pd.cmsprep_1_match_spec_t(
        as_fid=1,
        as_acc2=0
    )
)
p4_pd.cmsprep_1_table_add_with_hashcms_1_2(
    p4_pd.cmsprep_1_match_spec_t(
        as_fid=2,
        as_acc2=0
    )
)

p4_pd.cmscount_1_table_add_with_cms_count_1(
    p4_pd.cmscount_1_match_spec_t(
        as_acc2=0
    )
)

p4_pd.cmsprep_2_table_add_with_hashcms_2_1(
    p4_pd.cmsprep_2_match_spec_t(
        as_fid=1,
        as_acc2=0
    )
)
p4_pd.cmsprep_2_table_add_with_hashcms_2_2(
    p4_pd.cmsprep_2_match_spec_t(
        as_fid=2,
        as_acc2=0
    )
)

p4_pd.cmscount_2_table_add_with_cms_count_2(
    p4_pd.cmscount_2_match_spec_t(
        as_acc2=0
    )
)

p4_pd.cmsprep_3_table_add_with_hashcms_3_1(
    p4_pd.cmsprep_3_match_spec_t(
        as_fid=1,
        as_acc2=0
    )
)
p4_pd.cmsprep_3_table_add_with_hashcms_3_2(
    p4_pd.cmsprep_3_match_spec_t(
        as_fid=2,
        as_acc2=0
    )
)

p4_pd.cmscount_3_table_add_with_cms_count_3(
    p4_pd.cmscount_3_match_spec_t(
        as_acc2=0
    )
)

p4_pd.cmsprep_4_table_add_with_hashcms_4_1(
    p4_pd.cmsprep_4_match_spec_t(
        as_fid=1,
        as_acc2=0
    )
)
p4_pd.cmsprep_4_table_add_with_hashcms_4_2(
    p4_pd.cmsprep_4_match_spec_t(
        as_fid=2,
        as_acc2=0
    )
)

p4_pd.cmscount_4_table_add_with_cms_count_4(
    p4_pd.cmscount_4_match_spec_t(
        as_acc2=0
    )
)

p4_pd.storecms_table_add_with_storecmscount(
    p4_pd.storecms_match_spec_t(
        as_acc2=0
    )
)