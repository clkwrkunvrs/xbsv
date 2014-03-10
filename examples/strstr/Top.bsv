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
import Leds::*;
import BlueScope::*;
import PortalMemory::*;
import Dma::*;
import DmaUtils::*;
import AxiDma::*;

// generated by tool
import StrstrRequestWrapper::*;
import DmaConfigWrapper::*;
import StrstrIndicationProxy::*;
import DmaIndicationProxy::*;

// defined by user
import Strstr::*;

typedef enum {StrstrIndication, StrstrRequest, DmaIndication, DmaConfig} IfcNames deriving (Eq,Bits);

module mkPortalTop(StdPortalTop#(addrWidth)) 

   provisos(Add#(addrWidth, a__, 52),
	    Add#(b__, addrWidth, 64),
	    Add#(c__, 12, addrWidth),
	    Add#(addrWidth, d__, 44),
	    Add#(e__, c__, 40),
	    Add#(f__, addrWidth, 40));

   DmaIndicationProxy dmaIndicationProxy <- mkDmaIndicationProxy(DmaIndication);
   Vector#(2,DmaReadBuffer#(64,1)) haystack_read_chans <- replicateM(mkDmaReadBuffer());
   Vector#(2,DmaReadBuffer#(64,1)) needle_read_chans <- replicateM(mkDmaReadBuffer());
   Vector#(2,DmaReadBuffer#(64,1)) mp_next_read_chans <- replicateM(mkDmaReadBuffer());
   
   Vector#(6, DmaReadClient#(64)) readClients = newVector();
   readClients[0] = haystack_read_chans[0].dmaClient;
   readClients[1] = needle_read_chans[0].dmaClient;
   readClients[2] = mp_next_read_chans[0].dmaClient;
   readClients[3] = haystack_read_chans[1].dmaClient;
   readClients[4] = needle_read_chans[1].dmaClient;
   readClients[5] = mp_next_read_chans[1].dmaClient;

   Vector#(0, DmaWriteClient#(64)) writeClients = newVector();
   Integer numRequests = 8;
   AxiDmaServer#(addrWidth,64) dma <- mkAxiDmaServer(dmaIndicationProxy.ifc, numRequests, readClients, writeClients);
   DmaConfigWrapper dmaConfigWrapper <- mkDmaConfigWrapper(DmaConfig, dma.request);
   
   function DmaReadServer#(x) rs(DmaReadBuffer#(x,y) rb);
      return rb.dmaServer;
   endfunction
   
   StrstrIndicationProxy strstrIndicationProxy <- mkStrstrIndicationProxy(StrstrIndication);
   StrstrRequest strstrRequest <- mkStrstrRequest(strstrIndicationProxy.ifc, map(rs,haystack_read_chans), 
						  map(rs,needle_read_chans), map(rs,mp_next_read_chans));
   StrstrRequestWrapper strstrRequestWrapper <- mkStrstrRequestWrapper(StrstrRequest,strstrRequest);

   Vector#(4,StdPortal) portals;
   portals[0] = strstrRequestWrapper.portalIfc;
   portals[1] = strstrIndicationProxy.portalIfc; 
   portals[2] = dmaConfigWrapper.portalIfc;
   portals[3] = dmaIndicationProxy.portalIfc; 
   
   StdDirectory dir <- mkStdDirectory(portals);
   let ctrl_mux <- mkAxiSlaveMux(dir,portals);
   let interrupt_mux <- mkInterruptMux(portals);
   
   interface interrupt = interrupt_mux;
   interface ctrl = ctrl_mux;
   interface m_axi = dma.m_axi;
   interface leds = default_leds;
endmodule
