
MEMREADDIR=../../examples/memread
S2H = MemreadRequest
H2S = MemreadIndication
BSVFILES = $(MEMREADDIR)/Memread.bsv $(MEMREADDIR)/Top.bsv
CPPFILES = $(MEMREADDIR)/testmemread.cpp
CONNECTALFLAGS += -D NumEngineServers=16

#CONNECTALFLAGS += --bscflags " -show-schedule"
#CONNECTALFLAGS=--bscflags " -D TRACE_AXI"


include ../../Makefile.connectal
