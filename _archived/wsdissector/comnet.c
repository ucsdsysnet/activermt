#include "config.h"
#include <epan/packet.h>

#define COMNET_PORT 9876

static int proto_comnet = -1;
static int hf_comnet_pdu_binder = -1;
static int hf_comnet_pdu_flag = -1;
static int hf_comnet_pdu_demand = -1;
static int hf_comnet_pdu_fid = -1;
static int hf_comnet_pdu_acc = -1;
static int hf_comnet_pdu_acc2 = -1;
static gint ett_comnet = -1;

void proto_register_comnet(void) {
    static hf_register_info hf[] = {
        { &hf_comnet_pdu_binder,
            { "Comnet PDU Binder", "comnet.binder",
            FT_UINT8, BASE_DEC,
            NULL, 0x0,
            NULL, HFILL }
        },
        { &hf_comnet_pdu_flag,
            { "Comnet PDU Flag", "comnet.flag",
            FT_UINT8, BASE_DEC,
            NULL, 0x0,
            NULL, HFILL }
        },
        { &hf_comnet_pdu_demand,
            { "Comnet PDU Demand", "comnet.demand",
            FT_UINT8, BASE_DEC,
            NULL, 0x0,
            NULL, HFILL }
        },
        { &hf_comnet_pdu_fid,
            { "Comnet PDU FID", "comnet.fid",
            FT_UINT16, BASE_DEC,
            NULL, 0x0,
            NULL, HFILL }
        },
        { &hf_comnet_pdu_acc,
            { "Comnet PDU Accumulator", "comnet.acc",
            FT_UINT16, BASE_DEC,
            NULL, 0x0,
            NULL, HFILL }
        },
        { &hf_comnet_pdu_acc2,
            { "Comnet PDU 2nd Accumulator", "comnet.acc2",
            FT_UINT16, BASE_DEC,
            NULL, 0x0,
            NULL, HFILL }
        }
    };
    static gint *ett[] = {
        &ett_comnet
    };
    proto_comnet = proto_register_protocol(
        "Comnet Protocol",
        "Comnet",
        "comnet"
    );
    proto_register_field_array(proto_comnet, hf, array_length(hf));
    proto_register_subtree_array(ett, array_length(ett));
}

void proto_reg_handoff_comnet(void) {
    static dissector_handle_t comnet_handle;
    comnet_handle = create_dissector_handle(dissect_comnet, proto_comnet);
    dissector.add_uint("udp.port", COMNET_PORT, comnet_handle);
}

static int dissect_comnet(tvbuff_t *tvb, packet_info *pinfo, proto_tree *tree _U_, void *data _U_) {
    gint offset = 0;
    col_set_str(pinfo->cinfo, COL_PROTOCOL, "Comnet");
    col_clear(pinfo->cinfo, COL_INFO);
    proto_item *ti = proto_tree_add_item(tree, proto_comnet, tvb, 0, -1, ENC_NA);
    proto_tree *comnet_tree = proto_item_add_subtree(ti, ett_comnet);
    proto_tree_add_item(comnet_tree, hf_comnet_pdu_binder, tvb, offset, 1, ENC_BIG_ENDIAN);
    offset += 1;
    proto_tree_add_item(comnet_tree, hf_comnet_pdu_flag, tvb, offset, 1, ENC_BIG_ENDIAN);
    offset += 1;
    proto_tree_add_item(comnet_tree, hf_comnet_pdu_demand, tvb, offset, 1, ENC_BIG_ENDIAN);
    offset += 1;
    proto_tree_add_item(comnet_tree, hf_comnet_pdu_fid, tvb, offset, 2, ENC_BIG_ENDIAN);
    offset += 2;
    proto_tree_add_item(comnet_tree, hf_comnet_pdu_acc, tvb, offset, 2, ENC_BIG_ENDIAN);
    offset += 2;
    proto_tree_add_item(comnet_tree, hf_comnet_pdu_acc2, tvb, offset, 2, ENC_BIG_ENDIAN);
    return tvb_captured_length(tvb);
}