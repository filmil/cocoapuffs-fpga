-- SPDX-License-Identifier: Apache-2.0
package strings is
    type Item;
    type ItemP is access Item;

    --! Queue
    type Queue is record
        h, t: ItemP;
    end record;
    type QueueP is access Queue;

    function NewQueue return QueueP;
    procedure DeleteQueue(variable q: inout QueueP);
    procedure IsEmpty(variable q: in QueueP; empty: out boolean);
    procedure PushFront(variable q: inout QueueP;  v: in string);
    procedure PopBack(variable q: inout QueueP; v: out string; empty: out boolean);

    --private:

    constant MaxString: positive := 80;
    type Item is record
        v: string(1 to MaxString);
        p, n: Itemp;
    end record;

end package;

package body strings is

    function NewQueue return QueueP is
        variable ret: QueueP := null;
    begin
        ret := new Queue'(h => null, t => null);
        return ret;
    end function;

    procedure DeleteQueue(variable q: inout QueueP) is
        variable t: ItemP := q.h;
        variable n: ItemP;
    begin
        while t /= null loop
            n := t;
            t := t.n;
            deallocate(n);
        end loop;
        deallocate(q);
    end procedure;

    procedure IsEmpty(variable q: in QueueP; empty: out boolean) is
        variable ret: boolean := false;
    begin
        if q.h = null then
            ret := true;
        end if;
    end procedure;

    procedure PushFront(variable q: inout QueueP; v: in string) is
        variable i: ItemP;
        variable e: boolean;
    begin
        IsEmpty(q, e);
        i := new Item'(v => v, p => null, n => q.h);
        if e then
            q.h := i;
            q.t := i;
        end if;
    end procedure;

    procedure PopBack(variable q: inout QueueP; v: out string; empty: out boolean) is
        variable i: itemP;
        variable ve: boolean;
    begin
        IsEmpty(q, ve);
        empty := ve;
        if ve then
            return;
        end if;
        i := q.t;
        q.t := i.p;
        if q.h = i then q.h := i.n; end if;
        deallocate(i);
    end;

end package body;
