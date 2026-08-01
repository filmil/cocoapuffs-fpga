-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;

--! @file
--! @brief TileLink bus definitions and constants.

--! TileLink package.
package types is

    --! Width of the opcode field in bits.
    constant OPCODE_WIDTH: natural := 3;
    --! Width of the parameter field in bits.
    constant PARAM_WIDTH: natural := 3;
    --! Width of the size field in bits.
    constant SIZE_WIDTH: natural := 3;
    --! Width of the source identifier field in bits.
    constant SOURCE_WIDTH: natural := 8;
    --! Width of the sink identifier field in bits.
    constant SINK_WIDTH: natural := 8;
    --! Width of the address bus in bits.
    constant ADDRESS_WIDTH: natural := 32;
    --! Width of the byte mask in bits.
    constant MASK_WIDTH: natural := 4;
    --! Width of the data bus in bits.
    constant DATA_WIDTH: natural := 32;

    --! Opcode for PutFullData request.
    constant OP_PUT_FULL_DATA: std_ulogic_vector(OPCODE_WIDTH-1 downto 0) :=
        "000";
    --! Opcode for PutPartialData request.
    constant OP_PUT_PARTIAL_DATA: std_ulogic_vector(OPCODE_WIDTH-1 downto 0) :=
        "001";
    --! Opcode for ArithmeticData request.
    constant OP_ARITHMETIC_DATA: std_ulogic_vector(OPCODE_WIDTH-1 downto 0) :=
        "010";
    --! Opcode for LogicalData request.
    constant OP_LOGICAL_DATA: std_ulogic_vector(OPCODE_WIDTH-1 downto 0) :=
        "011";
    --! Opcode for Get request.
    constant OP_GET: std_ulogic_vector(OPCODE_WIDTH-1 downto 0) := "100";
    --! Opcode for Intent request.
    constant OP_INTENT: std_ulogic_vector(OPCODE_WIDTH-1 downto 0) := "101";
    --! Opcode for AcquireBlock request (TL-C).
    constant OP_ACQUIRE_BLOCK: std_ulogic_vector(OPCODE_WIDTH-1 downto 0) := "110";
    --! Opcode for AcquirePerm request (TL-C).
    constant OP_ACQUIRE_PERM: std_ulogic_vector(OPCODE_WIDTH-1 downto 0) := "111";

    --! ArithmeticData parameters
    constant PARAM_ARITH_MIN:  std_ulogic_vector(PARAM_WIDTH-1 downto 0) :=
        "000";
    constant PARAM_ARITH_MAX:  std_ulogic_vector(PARAM_WIDTH-1 downto 0) :=
        "001";
    constant PARAM_ARITH_MINU: std_ulogic_vector(PARAM_WIDTH-1 downto 0) :=
        "010";
    constant PARAM_ARITH_MAXU: std_ulogic_vector(PARAM_WIDTH-1 downto 0) :=
        "011";
    constant PARAM_ARITH_ADD:  std_ulogic_vector(PARAM_WIDTH-1 downto 0) :=
        "100";

    --! LogicalData parameters
    constant PARAM_LOGIC_XOR:  std_ulogic_vector(PARAM_WIDTH-1 downto 0) :=
        "000";
    constant PARAM_LOGIC_OR:   std_ulogic_vector(PARAM_WIDTH-1 downto 0) :=
        "001";
    constant PARAM_LOGIC_AND:  std_ulogic_vector(PARAM_WIDTH-1 downto 0) :=
        "010";
    constant PARAM_LOGIC_SWAP: std_ulogic_vector(PARAM_WIDTH-1 downto 0) :=
        "011";

    --! Opcode for AccessAck response.
    constant OP_ACCESS_ACK: std_ulogic_vector(OPCODE_WIDTH-1 downto 0) := "000";
    --! Opcode for AccessAckData response.
    constant OP_ACCESS_ACK_DATA: std_ulogic_vector(OPCODE_WIDTH-1 downto 0) :=
        "001";
    --! Opcode for Grant response (TL-C, permission only).
    constant OP_GRANT: std_ulogic_vector(OPCODE_WIDTH-1 downto 0) := "100";
    --! Opcode for GrantData response (TL-C, with data).
    constant OP_GRANT_DATA: std_ulogic_vector(OPCODE_WIDTH-1 downto 0) := "101";

    --! TileLink Channel A request record.
    type a_type is record
        --! Opcode of the request.
        opcode: std_ulogic_vector(OPCODE_WIDTH-1 downto 0);
        --! Parameter associated with the opcode.
        param: std_ulogic_vector(PARAM_WIDTH-1 downto 0);
        --! Size of the operation as 2^size bytes.
        size: std_ulogic_vector(SIZE_WIDTH-1 downto 0);
        --! Source identifier.
        source: std_ulogic_vector(SOURCE_WIDTH-1 downto 0);
        --! Address of the operation.
        address: std_ulogic_vector(ADDRESS_WIDTH-1 downto 0);
        --! Byte mask for partial writes.
        mask: std_ulogic_vector(MASK_WIDTH-1 downto 0);
        --! Data for write operations.
        data: std_ulogic_vector(DATA_WIDTH-1 downto 0);
        --! Set if data is known to be corrupt.
        corrupt: std_ulogic;
        --! Valid signal for Channel A.
        valid: std_ulogic;
    end record;

    --! Initializer for a_type.
    constant a_type_new: a_type := (
        opcode => (others => '0'),
        param => (others => '0'),
        size => (others => '0'),
        source => (others => '0'),
        address => (others => '0'),
        mask => (others => '0'),
        data => (others => '0'),
        corrupt => '0',
        valid => '0'
    );

    --! TileLink Channel D response record.
    type d_type is record
        --! Opcode of the response.
        opcode: std_ulogic_vector(OPCODE_WIDTH-1 downto 0);
        --! Parameter associated with the opcode.
        param: std_ulogic_vector(PARAM_WIDTH-1 downto 0);
        --! Size of the operation as 2^size bytes.
        size: std_ulogic_vector(SIZE_WIDTH-1 downto 0);
        --! Source identifier (from the request).
        source: std_ulogic_vector(SOURCE_WIDTH-1 downto 0);
        --! Sink identifier.
        sink: std_ulogic_vector(SINK_WIDTH-1 downto 0);
        --! Data for read responses.
        data: std_ulogic_vector(DATA_WIDTH-1 downto 0);
        --! Set if data is known to be corrupt.
        corrupt: std_ulogic;
        --! Valid signal for Channel D.
        valid: std_ulogic;
    end record;

    --! Initializer for d_type.
    constant d_type_new: d_type := (
        opcode => (others => '0'),
        param => (others => '0'),
        size => (others => '0'),
        source => (others => '0'),
        sink => (others => '0'),
        data => (others => '0'),
        corrupt => '0',
        valid => '0'
    );

    --! TileLink host (master) side bus.
    type host_type is record
        --! Request channel.
        a: a_type;
        --! Back-pressure signal for response channel.
        d_ready: std_ulogic;
    end record;

    --! Initializer for host_type.
    constant host_type_new: host_type := (
        a => a_type_new,
        d_ready => '0'
    );

    --! TileLink peripheral (slave) side bus.
    type per_type is record
        --! Back-pressure signal for request channel.
        a_ready: std_ulogic;
        --! Response channel.
        d: d_type;
    end record;

    --! Initializer for per_type.
    constant per_type_new: per_type := (
        a_ready => '0',
        d => d_type_new
    );


    --! TileLink Channel B probe record.
    type b_type is record
        --! Opcode of the probe.
        opcode: std_ulogic_vector(OPCODE_WIDTH-1 downto 0);
        --! Parameter associated with the opcode.
        param: std_ulogic_vector(PARAM_WIDTH-1 downto 0);
        --! Size of the operation.
        size: std_ulogic_vector(SIZE_WIDTH-1 downto 0);
        --! Source identifier.
        source: std_ulogic_vector(SOURCE_WIDTH-1 downto 0);
        --! Address of the operation.
        address: std_ulogic_vector(ADDRESS_WIDTH-1 downto 0);
        --! Byte mask.
        mask: std_ulogic_vector(MASK_WIDTH-1 downto 0);
        --! Data.
        data: std_ulogic_vector(DATA_WIDTH-1 downto 0);
        --! Corrupt flag.
        corrupt: std_ulogic;
        --! Valid signal.
        valid: std_ulogic;
    end record;

    --! Initializer for b_type.
    constant b_type_new: b_type := (
        opcode => (others => '0'),
        param => (others => '0'),
        size => (others => '0'),
        source => (others => '0'),
        address => (others => '0'),
        mask => (others => '0'),
        data => (others => '0'),
        corrupt => '0',
        valid => '0'
    );

    --! TileLink Channel C release/probeAck record.
    type c_type is record
        --! Opcode of the release.
        opcode: std_ulogic_vector(OPCODE_WIDTH-1 downto 0);
        --! Parameter associated with the opcode.
        param: std_ulogic_vector(PARAM_WIDTH-1 downto 0);
        --! Size of the operation.
        size: std_ulogic_vector(SIZE_WIDTH-1 downto 0);
        --! Source identifier.
        source: std_ulogic_vector(SOURCE_WIDTH-1 downto 0);
        --! Address of the operation.
        address: std_ulogic_vector(ADDRESS_WIDTH-1 downto 0);
        --! Data.
        data: std_ulogic_vector(DATA_WIDTH-1 downto 0);
        --! Corrupt flag.
        corrupt: std_ulogic;
        --! Valid signal.
        valid: std_ulogic;
    end record;

    --! Initializer for c_type.
    constant c_type_new: c_type := (
        opcode => (others => '0'),
        param => (others => '0'),
        size => (others => '0'),
        source => (others => '0'),
        address => (others => '0'),
        data => (others => '0'),
        corrupt => '0',
        valid => '0'
    );

    --! TileLink Channel E grantAck record.
    type e_type is record
        --! Sink identifier.
        sink: std_ulogic_vector(SINK_WIDTH-1 downto 0);
        --! Valid signal.
        valid: std_ulogic;
    end record;

    --! Initializer for e_type.
    constant e_type_new: e_type := (
        sink => (others => '0'),
        valid => '0'
    );

    --! TileLink Cached host (master) side bus.
    type host_type_c is record
        --! Request channel.
        a: a_type;
        --! Release/ProbeAck channel.
        c: c_type;
        --! GrantAck channel.
        e: e_type;
        --! Back-pressure signal for probe channel.
        b_ready: std_ulogic;
        --! Back-pressure signal for response channel.
        d_ready: std_ulogic;
    end record;

    --! Initializer for host_type_c.
    constant host_type_c_new: host_type_c := (
        a => a_type_new,
        c => c_type_new,
        e => e_type_new,
        b_ready => '0',
        d_ready => '0'
    );

    --! TileLink Cached peripheral (slave) side bus.
    type per_type_c is record
        --! Back-pressure signal for request channel.
        a_ready: std_ulogic;
        --! Probe channel.
        b: b_type;
        --! Back-pressure signal for release/probeAck channel.
        c_ready: std_ulogic;
        --! Response channel.
        d: d_type;
        --! Back-pressure signal for grantAck channel.
        e_ready: std_ulogic;
    end record;

    --! Initializer for per_type_c.
    constant per_type_c_new: per_type_c := (
        a_ready => '0',
        b => b_type_new,
        c_ready => '0',
        d => d_type_new,
        e_ready => '0'
    );

end package;
