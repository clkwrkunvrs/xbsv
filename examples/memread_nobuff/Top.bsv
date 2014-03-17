// bsv libraries
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;

// portz libraries
import AxiMasterSlave::*;
import Directory::*;
import CtrlMux::*;
import Portal::*;
import PortalMemory::*;
import Dma::*;
import AxiDma::*;
import Leds::*;

// generated by tool
import MemreadRequestWrapper::*;
import DmaConfigWrapper::*;
import MemreadIndicationProxy::*;
import DmaIndicationProxy::*;

// defined by user
import Memread::*;

typedef enum {MemreadIndication, MemreadRequest, DmaIndication, DmaConfig} IfcNames deriving (Eq,Bits);

module mkPortalTop(StdPortalTop#(addrWidth)) 

   provisos(Add#(addrWidth, a__, 52),
	    Add#(b__, addrWidth, 64),
	    Add#(c__, 12, addrWidth),
	    Add#(addrWidth, d__, 44),
	    Add#(e__, c__, DmaOffsetSize),
	    Add#(f__, addrWidth, 40));

   MemreadIndicationProxy memreadIndicationProxy <- mkMemreadIndicationProxy(MemreadIndication);
   Memread memread <- mkMemread(memreadIndicationProxy.ifc);
   MemreadRequestWrapper memreadRequestWrapper <- mkMemreadRequestWrapper(MemreadRequest,memread.request);

   Vector#(1, DmaReadClient#(64)) clients = cons(memread.dmaClient, nil);
   DmaIndicationProxy dmaIndicationProxy <- mkDmaIndicationProxy(DmaIndication);
   AxiDmaServer#(addrWidth,64) dma <- mkAxiDmaServer(dmaIndicationProxy.ifc, clients, nil);
   DmaConfigWrapper dmaRequestWrapper <- mkDmaConfigWrapper(DmaConfig,dma.request);

   Vector#(4,StdPortal) portals;
   portals[0] = memreadRequestWrapper.portalIfc;
   portals[1] = memreadIndicationProxy.portalIfc; 
   portals[2] = dmaRequestWrapper.portalIfc;
   portals[3] = dmaIndicationProxy.portalIfc; 
   
   StdDirectory dir <- mkStdDirectory(portals);
   let ctrl_mux <- mkAxiSlaveMux(dir,portals);
   let interrupt_mux <- mkInterruptMux(portals);
   
   interface interrupt = interrupt_mux;
   interface ctrl = ctrl_mux;
   interface m_axi = dma.m_axi;
   interface leds = default_leds;
      
endmodule : mkPortalTop
