# ###############################################################################################           
#                                                                                               #
# Verification Goal: Set pte.r=0 & pte.w=0 & pte.x=1 & s/mstatus.MXR=0 and test the read acces	#
#		     for level 0 PTE in Supervisor mode,Should raise load page fault.		#
#												#												#											
# Description:       If PTE has only execute permission (pte.x = 1) and s/mstatus.MXR=0, then 	#
#		     read access on that PTE should raise load page fault exception.		#
# ###############################################################################################        
  
#include "model_test.h"

#include "arch_test.h"

RVTEST_ISA("RV32I_Zicsr")

# Test code region
.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
#ifdef TEST_CASE_1
    RVTEST_CASE(1,"//check ISA:=regex(.*32.*); check ISA:=regex(.*I.*Zicsr.*); def rvtest_mtrap_routine=True; def rvtest_strap_routine=True; def TEST_CASE_1=True",sv32)

RVTEST_SIGBASE( x13,signature_x13_1)
  	
main:
# ---------------------------------------------------------------------------------------------

#ifdef rvtest_mtrap_routine					                // Verification of existance of rvtest_mtrap_routine
	LI a4, 0xceed
	RVTEST_SIGUPD(x13,a4)
#endif
#ifdef rvtest_strap_routine					                // Verification of existance of rvtest_strap_routine
	LI a4, 0xbeed
	RVTEST_SIGUPD(x13,a4)
#endif
	
	ALL_MEM_PMP          		                                        // set the PMP permissions
	csrw satp,x0	 		                                        // write satp with all zeros (bare mode)

	.set va,		0x90000000
	.set pa,		0x80000000 
	.set va_data,	        0x90011000                                      // MSB 10 bits should be same as that of va 
        .set sig_data,          0x93003110                                      // virtual address of signature_x13_1
                                                                                // PTE setup for sig_data -> rvtest_slvl1_pg_tbl*/
	la a0, rvtest_slvl1_pg_tbl   		                                // loads the base address of the pg_tbl0        				
	li a1, (PTE_V)                                                          // sets the permissions bits                
	PTE_SETUP_RV32(a0, a1, t0, t1, sig_data, LEVEL1)	                // setup the PTE for level1 
                                                     				// PTE setup for Instruction memory 0x90000000 -> 0x80000000                                             			                // pgtbl1 PTE Setup to point to the pgtbl0 PTE
	LA (a0, rvtest_slvl1_pg_tbl)                                            // stores the base address of pgtbl0 address in a0
	LI (a1, PTE_V)                                                          // sets the PR bit to valid only to point to the pgtbl0 PTE
	PTE_SETUP_RV32(a0, a1, t0, t1, va, LEVEL1)                              // setup the PTE for level1
     
                                             		                        // PTE setup for Instruction memory 0x90000000 -> 0x80000000
	LA (a0, pa)                                                             // loads the address in a0
	LI a1, ( PTE_D | PTE_A | PTE_X | PTE_V )               			// sets the permission bits
	PTE_SETUP_RV32(a0, a1, t0, t1, va, LEVEL0)                              // setup the PTE for level1
								                // PTE setup for rvtest_data 0x91000000 -> rvtest_data	
	LA (a0, rvtest_data)                                                    // loads the address of label rvtest_data in a0
	LI a1, ( PTE_D | PTE_A | PTE_X | PTE_V )               			// sets the permission bits
	PTE_SETUP_RV32(a0, a1, t0, t1, va_data, LEVEL0)                         // setup the PTE for level1
                                                                                // PTE setup for 0x93003114 -> signature_x13_1
	la a0, rvtest_sig_begin   						// Physical address of signature area
	li a1, ( PTE_D | PTE_A | PTE_R | PTE_W | PTE_X | PTE_V)                 // sets the permissions bits 
	PTE_SETUP_RV32(a0, a1, t0, t1, sig_data, LEVEL0) 			// PTE Setup for signature area address at pgtbl0

	LI (t0, sig_data)                                                       
	LA (t1, rvtest_sig_begin)                                                      
	sub t0, t0, t1 					        		// (VA-PA) Note: VA > PA 
	add s11, x13, t0				        		// Translation of Signature reg

        SATP_SETUP_SV32                                                         // set the SATP for virtualization

# -------------------------Save area logic----------------------------------

	SIGNATURE_AREA (CODE, va, pa)						// signature area for code 
	SIGNATURE_AREA (DATA, va_data,rvtest_data)				// signature area for data 
	SIGNATURE_AREA (SIG, sig_data, signature_x13_1)				// signature area for signature 
	SIGNATURE_AREA (VMEM, va_data, rvtest_data)				// signature area for vmem

	sfence.vma                                                              // flush the TLB
	li s7, MSTATUS_MXR
        csrc mstatus,s7	                                                        // clear the mstatus.MXR = 0 
	RVTEST_GOTO_LOWER_MODE	Smode		                                // Switching to S mode

vm_en:
	LI (a4, 0xdead)
	RVTEST_SIGUPD(x13,a4)                                                   // Verification of virtualization enabeled

	LI (t0, va_data)                                                        
	LREG x2, 0(t0)                                                          // test the load access  (should raise an exception)
        nop                                             
	
	LI (a4, 0xbeef)
	RVTEST_SIGUPD(x13,a4)                                                   // Verification of virtualization enabeled
        nop

# -------------------------virtulization disabled----------------------------------

	RVTEST_GOTO_MMODE		                                        // Switching back to M mode

	LI (t0, sig_data)                                                       
	LA (t1, rvtest_sig_begin)                                                      
	sub t0, t0, t1 					        		// (VA-PA) Note: VA > PA 
	sub x13, x13, t0				        		// Translation of Signature reg
	addi x13,x13,REGWIDTH
	nop

	LI (a4, 0x123)
	RVTEST_SIGUPD(x13,a4)                                                   // Verification of virtualization disabled
#endif

 # ---------------------------------------------------------------------------------------------
RVTEST_CODE_END
RVMODEL_HALT

RVTEST_DATA_BEGIN
.align 24
rvtest_data:
.word 0xbeefcafe
.word 0xbabecafe
.word 0xbabecafe
.word 0xbabecafe
#ifdef rvtest_strap_routine
.align 12
rvtest_slvl1_pg_tbl:
		RVTEST_PTE_IDENT_MAP
#endif
RVTEST_DATA_END
RVMODEL_DATA_BEGIN
rvtest_sig_begin:
sig_begin_canary:
CANARY;

// test signatures initialization
signature_x13_1:
    .fill 32*(XLEN/32),4,0xcafebeef

// trap signatures initialization
#ifdef rvtest_mtrap_routine
mtrap_sigptr:
    .fill 32*(XLEN/32),4,0xdeadbeef
#endif

sig_end_canary:
CANARY;
rvtest_sig_end:
RVMODEL_DATA_END