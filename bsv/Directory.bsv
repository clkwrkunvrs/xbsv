// bsv libraries
import Vector::*;
import FIFO::*;
import RegFile::*;

//portz libraries
import Portal::*;
import AxiMasterSlave::*;

interface Directory;
   interface StdPortal portalIfc;
endinterface

module mkDirectory#(Vector#(n,StdPortal) portals) (Directory);
   
   let rf = (interface RegFile#(Bit#(32), Bit#(32));
		method Action upd(Bit#(32) addr, Bit#(32) data);
		   noAction;
		endmethod
		method Bit#(32) sub(Bit#(32) addr);
		   if (addr == 0)
		      return 0; // directory version
		   else if (addr == 1)
		      return `TimeStamp;
		   else if (addr == 2)
		      return fromInteger(valueOf(n));
		   else if (addr == 3)
		      return 16; // portal Addr bits
		   else if (addr < fromInteger(valueOf(TAdd#(TMul#(2,n),4)))) begin
		      let idx = (addr-4);
		      if (idx[0] == 0)
			 return portals[idx<<1].ifcId;
		      else
			 return portals[idx<<1].ifcType;
		   end
		   else
		      return 0;
		endmethod
      	     endinterface);
   StdAxi3Slave ctrl_mod <- mkAxi3SlaveFromRegFile(rf);

   interface StdPortal portalIfc;
      method Bit#(32) ifcId();
	 return 0;
      endmethod
      method Bit#(32) ifcType();
	 return 0;
      endmethod
      interface Axi3Slave ctrl = ctrl_mod;
      interface ReadOnly interrupt;
	 method Bool _read;
	    return False;
	 endmethod
      endinterface
   endinterface

endmodule

