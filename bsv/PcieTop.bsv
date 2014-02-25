// Copyright (c) 2014 Quanta Research Cambridge, Inc.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Vector            :: *;
import Connectable       :: *;
import Xilinx            :: *;
//import XilinxPCIE        :: *;
import PcieToAxiBridge   :: *;
import Portal            :: *;
import Leds              :: *;
import Top               :: *;

typedef (function Module#(PortalTop#(40, dsz, ipins)) mkPortalTop()) MkPortalTop#(numeric type dsz, type ipins);

`ifdef Artix7
typedef 4 PcieLanes;
`else
typedef 8 PcieLanes;
`endif

interface PcieTop#(type ipins);
   (* prefix="PCIE" *)
   interface PCIE_EXP#(PcieLanes) pcie;
   (* always_ready *)
   method Bit#(8) leds();
   interface ipins       pins;
endinterface
	    
(* no_default_clock, no_default_reset *)
module [Module] mkPcieTopFromPortal #(Clock pci_sys_clk_p, Clock pci_sys_clk_n,
				      Clock sys_clk_p,     Clock sys_clk_n,
				      Reset pci_sys_reset_n,
				      MkPortalTop#(dsz, ipins) mkPortalTop)
   (PcieTop#(ipins))
   provisos (Mul#(TDiv#(dsz, 32), 32, dsz),
	     Add#(b__, 32, dsz),
	     Add#(c__, dsz, 256),
	     Add#(d__, TMul#(8, TDiv#(dsz, 32)), 64),
	     Add#(e__, TMul#(32, TDiv#(dsz, 32)), 256),
	     Add#(f__, TDiv#(dsz, 32), 8)
      );

   let contentId = 0;

   X7PcieBridgeIfc#(PcieLanes) x7pcie <- mkX7PcieBridge( pci_sys_clk_p, pci_sys_clk_n, sys_clk_p, sys_clk_n, pci_sys_reset_n,
							contentId );
   
   Reg#(Bool) interruptRequested <- mkReg(False, clocked_by x7pcie.clock125, reset_by x7pcie.reset125);

   // instantiate user portals
   let portalTop <- mkPortalTop(clocked_by x7pcie.clock125, reset_by x7pcie.portalReset);
   let m_axi = portalTop.m_axi;
   AxiSlaveEngine#(dsz) axiSlaveEngine <- mkAxiSlaveEngine(x7pcie.pciId(), clocked_by x7pcie.clock125, reset_by x7pcie.reset125);
   mkConnection(tpl_1(x7pcie.slave), tpl_2(axiSlaveEngine.tlps), clocked_by x7pcie.clock125, reset_by x7pcie.reset125);
   mkConnection(tpl_1(axiSlaveEngine.tlps), tpl_2(x7pcie.slave), clocked_by x7pcie.clock125, reset_by x7pcie.reset125);
   mkConnection(portalTop.m_axi, axiSlaveEngine.slave3, clocked_by x7pcie.clock125, reset_by x7pcie.reset125);

   mkConnection(x7pcie.portal0, portalTop.ctrl, clocked_by x7pcie.clock125, reset_by x7pcie.reset125);

   rule requestInterrupt;
      if (portalTop.interrupt && !interruptRequested)
	 x7pcie.interrupt();
      interruptRequested <= portalTop.interrupt;
   endrule

   interface pcie = x7pcie.pcie;
   //interface ddr3 = x7pcie.ddr3;
   method Bit#(8) leds();
      return 0;
   endmethod
   interface pins = portalTop.pins;

endmodule: mkPcieTopFromPortal

