      module GwfEvtSubs
        
        use GwfEvtModule, only: SGWF2EVT7PNT, SGWF2EVT7PSV
        
      contains
      
      SUBROUTINE GWF2EVT7AR(IN,IGRID)
C     ******************************************************************
C     ALLOCATE ARRAY STORAGE FOR EVAPOTRANSPIRATION
C     ******************************************************************
C
C        SPECIFICATIONS:
C     ------------------------------------------------------------------
      USE GLOBAL,      ONLY:IOUT,NCOL,NROW,IFREFM
      USE GWFEVTMODULE,ONLY:NEVTOP,IEVTCB,NPEVT,IEVTPF,EVTR,EXDP,SURF,
     1                      IEVT
      use utl7module, only: U1DREL, U2DREL, !UBDSV1, UBDSV2, UBDSVA,
     &                      urword, URDCOM, !UBDSV4, UBDSVB,
     &                      ULSTRD
      use SimPHMFModule, only: ustop
C
      CHARACTER*200 LINE
      CHARACTER*4 PTYP
      double precision :: r
C     ------------------------------------------------------------------
C
C1------ALLOCATE SCALAR VARIABLES.
      ALLOCATE(NEVTOP,IEVTCB)
      ALLOCATE(NPEVT,IEVTPF)
C
C2------IDENTIFY PACKAGE.
      IEVTPF=0
      WRITE(IOUT,1)IN
    1 FORMAT(1X,/1X,'EVT -- EVAPOTRANSPIRATION PACKAGE, VERSION 7,',
     1     ' 5/2/2005',/,9X,'INPUT READ FROM UNIT ',I4)
C
C3------READ ET OPTION (NEVTOP) AND UNIT OR FLAG FOR CELL-BY-CELL FLOW
C3------TERMS (IEVTCB).
      CALL URDCOM(IN,IOUT,LINE)
      CALL UPARARRAL(IN,IOUT,LINE,NPEVT)
      IF(IFREFM.EQ.0) THEN
         READ(LINE,'(2I10)') NEVTOP,IEVTCB
      ELSE
         LLOC=1
         CALL URWORD(LINE,LLOC,ISTART,ISTOP,2,NEVTOP,R,IOUT,IN)
         CALL URWORD(LINE,LLOC,ISTART,ISTOP,2,IEVTCB,R,IOUT,IN)
      END IF
C
C4------CHECK TO SEE THAT ET OPTION IS LEGAL.
      IF(NEVTOP.GE.1.AND.NEVTOP.LE.3)GO TO 200
C
C4A-----OPTION IS ILLEGAL -- PRINT A MESSAGE & ABORT SIMULATION.
      WRITE(IOUT,8) NEVTOP
    8 FORMAT(1X,'ILLEGAL ET OPTION CODE (NEVTOP = ',I5,
     1       ') -- SIMULATION ABORTING')
      CALL USTOP(' ')
C
C5------OPTION IS LEGAL -- PRINT THE OPTION CODE.
  200 IF(NEVTOP.EQ.1) WRITE(IOUT,201)
  201 FORMAT(1X,'OPTION 1 -- EVAPOTRANSPIRATION FROM TOP LAYER')
      IF(NEVTOP.EQ.2) WRITE(IOUT,202)
  202 FORMAT(1X,'OPTION 2 -- EVAPOTRANSPIRATION FROM ONE SPECIFIED',
     1   ' NODE IN EACH VERTICAL COLUMN')
      IF(NEVTOP.EQ.3) WRITE(IOUT,203)
  203 FORMAT(1X,'OPTION 3 -- EVAPOTRANSPIRATION FROM HIGHEST ACTIVE',
     1   ' NODE IN EACH VERTICAL COLUMN')
C
C6------IF CELL-BY-CELL FLOWS ARE TO BE SAVED, THEN PRINT UNIT NUMBER.
      IF(IEVTCB.GT.0) WRITE(IOUT,204) IEVTCB
  204 FORMAT(1X,'CELL-BY-CELL FLOWS WILL BE SAVED ON UNIT ',I4)
C
C7------ALLOCATE SPACE FOR THE ARRAYS EVTR, EXDP, SURF, AND IEVT.
      ALLOCATE (EVTR(NCOL,NROW))
      ALLOCATE (EXDP(NCOL,NROW))
      ALLOCATE (SURF(NCOL,NROW))
      ALLOCATE (IEVT(NCOL,NROW))
C
C8------READ NAMED PARAMETERS
      WRITE(IOUT,5) NPEVT
    5 FORMAT(1X,//1X,I5,' Evapotranspiration parameters')
      IF(NPEVT.GT.0) THEN
         DO 20 K=1,NPEVT
         CALL UPARARRRP(IN,IOUT,N,0,PTYP,1,1,0)
         IF(PTYP.NE.'EVT') THEN
            WRITE(IOUT,7)
    7       FORMAT(1X,'Parameter type must be EVT')
            CALL USTOP(' ')
         END IF
   20    CONTINUE
      END IF
C
C9------RETURN
      CALL SGWF2EVT7PSV(IGRID)
      RETURN
      END SUBROUTINE GWF2EVT7AR

C*******************************************************************************

      SUBROUTINE GWF2EVT7RP(IN,IGRID)
C     ******************************************************************
C     READ EVAPOTRANSPIRATION DATA
C     ******************************************************************
C
C        SPECIFICATIONS:
C     ------------------------------------------------------------------
      USE GLOBAL,      ONLY:IOUT,NCOL,NROW,NLAY,DELR,DELC,IFREFM
      USE GWFEVTMODULE,ONLY:NEVTOP,NPEVT,IEVTPF,EVTR,EXDP,SURF,IEVT
      use utl7module, only: U1DREL, U2DREL, !UBDSV1, UBDSV2, UBDSVA,
     &                      urword, URDCOM, !UBDSV4, UBDSVB,
     &                      ULSTRD, u2dint
      use SimPHMFModule, only: ustop
C
      CHARACTER*24 ANAME(4)
C
      DATA ANAME(1) /'          ET LAYER INDEX'/
      DATA ANAME(2) /'              ET SURFACE'/
      DATA ANAME(3) /' EVAPOTRANSPIRATION RATE'/
      DATA ANAME(4) /'        EXTINCTION DEPTH'/
C     ------------------------------------------------------------------
C
C1------SET POINTERS FOR THE CURRENT GRID.
      CALL SGWF2EVT7PNT(IGRID)
C
C2------READ FLAGS SHOWING WHETHER DATA IS TO BE REUSED.
      IF(NEVTOP.EQ.2) THEN
         IF(IFREFM.EQ.0) THEN
            READ(IN,'(4I10)') INSURF,INEVTR,INEXDP,INIEVT
         ELSE
            READ(IN,*) INSURF,INEVTR,INEXDP,INIEVT
         END IF
      ELSE
         IF(IFREFM.EQ.0) THEN
            READ(IN,'(3I10)') INSURF,INEVTR,INEXDP
         ELSE
            READ(IN,*) INSURF,INEVTR,INEXDP
         END IF
      END IF
C
C3------TEST INSURF TO SEE WHERE SURFACE ELEVATION COMES FROM.
      IF(INSURF.LT.0) THEN
C
C3A------INSURF<0, SO REUSE SURFACE ARRAY FROM LAST STRESS PERIOD.
        WRITE(IOUT,3)
    3   FORMAT(1X,/1X,'REUSING SURF FROM LAST STRESS PERIOD')
      ELSE
C
C3B------INSURF=>0, SO CALL MODULE U2DREL TO READ SURFACE.
        CALL U2DREL(SURF,ANAME(2),NROW,NCOL,0,IN,IOUT)
      END IF
C
C4------TEST INEVTR TO SEE WHERE MAX ET RATE (EVTR) COMES FROM.
      IF(INEVTR.LT.0) THEN
C
C4A-----INEVTR<0, SO REUSE EVTR FROM LAST STRESS PERIOD.
        WRITE(IOUT,4)
    4   FORMAT(1X,/1X,'REUSING EVTR FROM LAST STRESS PERIOD')
      ELSE
C
C4B-----INEVTR=>0, SO READ MAX ET RATE.
        IF(NPEVT.EQ.0) THEN
C
C4B1----THERE ARE NO PARAMETERS,SO READ EVTR USING U2DREL
          CALL U2DREL(EVTR,ANAME(3),NROW,NCOL,0,IN,IOUT)
        ELSE
C
C4B2----DEFINE EVTR USING PARAMETERS. INEVTR IS THE NUMBER OF
C4B2----PARAMETERS TO USE THIS STRESS PERIOD.
          CALL PRESET('EVT')
          WRITE(IOUT,33)
   33     FORMAT(1X,///1X,
     1      'EVTR array defined by the following parameters:')
          IF (INEVTR.EQ.0) THEN
            WRITE(IOUT,34)
   34       FORMAT(' ERROR: When parameters are defined for the EVT',
     &     ' Package, at least one parameter',/,' must be specified',
     &     ' each stress period -- STOP EXECUTION (GWF2EVT7RPSS)')
            CALL USTOP(' ')
          END IF
          CALL UPARARRSUB2(EVTR,NCOL,NROW,0,INEVTR,IN,IOUT,'EVT',
     1        ANAME(3),'EVT',IEVTPF)
        END IF
C
C5------MULTIPLY MAX ET RATE BY CELL AREA TO GET VOLUMETRIC RATE
        DO 40 IR=1,NROW
        DO 40 IC=1,NCOL
        EVTR(IC,IR)=EVTR(IC,IR)*DELR(IC)*DELC(IR)
   40   CONTINUE
      END IF
C
C6------TEST INEXDP TO SEE WHERE EXTINCTION DEPTH COMES FROM
      IF(INEXDP.LT.0) THEN
C
C6A------IF INEXDP<0 REUSE EXTINCTION DEPTH FROM LAST STRESS PERIOD
        WRITE(IOUT,5)
    5   FORMAT(1X,/1X,'REUSING EXDP FROM LAST STRESS PERIOD')
      ELSE
C
C6B------IF INEXDP=>0 CALL MODULE U2DREL TO READ EXTINCTION DEPTH
        CALL U2DREL(EXDP,ANAME(4),NROW,NCOL,0,IN,IOUT)
      END IF
C
C7------IF OPTION(NEVTOP) IS 2 THEN WE NEED AN INDICATOR ARRAY.  TEST
C7------INIEVT TO SEE HOW TO DEFINE IEVT.
      IF(NEVTOP.EQ.2) THEN
        IF(INIEVT.LT.0) THEN
C
C7A------IF INIEVT<0 THEN REUSE LAYER INDICATOR ARRAY.
          WRITE(IOUT,2)
    2     FORMAT(1X,/1X,'REUSING IEVT FROM LAST STRESS PERIOD')
        ELSE
C
C7B------IF INIEVT=>0 THEN CALL MODULE U2DINT TO READ INDICATOR ARRAY.
   49     CALL U2DINT(IEVT,ANAME(1),NROW,NCOL,0,IN,IOUT)
          DO 57 IR=1,NROW
          DO 57 IC=1,NCOL
          IF(IEVT(IC,IR).LT.1 .OR. IEVT(IC,IR).GT.NLAY) THEN
            WRITE(IOUT,56) IC,IR,IEVT(IC,IR)
   56       FORMAT(1X,/1X,'INVALID LAYER NUMBER IN IEVT FOR COLUMN',I4,
     1           '  ROW',I4,'  :',I4)
            CALL USTOP(' ')
          END IF
   57     CONTINUE
        END IF
      END IF
C
C8------RETURN
      RETURN
      END SUBROUTINE GWF2EVT7RP

      end module GwfEvtSubs
      
