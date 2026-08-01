-- SPDX-License-Identifier: Apache-2.0
package testlib is
    procedure print(msg : string);
end package;

package body testlib is
    procedure print(msg : string) is
    begin
        null;
    end procedure;
end package body;

package riscv_disas is
    -- Empty dummy package to satisfy unused imports in Vivado synthesis
end package;
