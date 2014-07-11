// bsv libraries
import Vector::*;
import FIFO::*;
import Connectable::*;

// portz libraries
import Directory::*;
import CtrlMux::*;
import Portal::*;
import Leds::*;
import MemTypes::*;

// generated by tool
import PcieTestBenchIndicationProxy::*;
import PcieTestBenchRequestWrapper::*;

// defined by user
import PcieTestBench::*;

module mkPortalTop(StdPortalDmaTop#(40));

   // instantiate user portals
   PcieTestBenchIndicationProxy pcieTestBenchIndicationProxy <- mkPcieTestBenchIndicationProxy(TestBenchIndication);
   PcieTestBench#(40,64) pcieTestBench <- mkPcieTestBench(pcieTestBenchIndicationProxy.ifc);
   PcieTestBenchRequestWrapper pcieTestBenchRequestWrapper <- mkPcieTestBenchRequestWrapper(TestBenchRequest,pcieTestBench.request);
   
   Vector#(4,StdPortal) portals;
   portals[0] = pcieTestBenchRequestWrapper.portalIfc; 
   portals[1] = pcieTestBenchIndicationProxy.portalIfc;
   portals[2] = pcieTestBench.dmaConfig;
   portals[3] = pcieTestBench.dmaIndication;
   
   // instantiate system directory
   StdDirectory dir <- mkStdDirectory(portals);
   let ctrl_mux <- mkSlaveMux(dir,portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = pcieTestBench.masters;
   interface leds = default_leds;

endmodule : mkPortalTop

