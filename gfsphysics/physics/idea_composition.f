      module idea_composition
!-------------------------------------------------------------------------
! hold composition of O O2 N2
! Apr 06 2012   Henry Juang, initial implement  into NEMS
! Mar 08 2012   Jun Wang,    add fields for restart
! Oct 20 2015   Weiyu Yang,  move f107 and kp to atmos/phys/wam_f107_kp_mod.
! Oct    2016   VAY          Add parameters & lev_wam for WAM-physics
!                            like WAM-constants list should be here
! May    2020   Sajal Kar    Update idea_composition_init for 149-layer FV3-WAM
!-------------------------------------------------------------------------
      implicit none
!
      integer :: mpi_me, mpi_master
!
!SK   integer , parameter::lev_wam = 150                  ! # of wam vertical layers
      integer , parameter::lev_wam = 149                  ! # of wam vertical layers
!
      real , parameter:: amo =15.9994                     ! molecular wght of O   ! (g/mol) 
      real , parameter:: amn2=28.013                      ! molecular wght of N2 
      real , parameter:: amo2 =2.*amo                     ! molecular wght of O2  ! (g/mol) 
      real , parameter:: amo3 =3.*amo                     ! molecular wght of O3  ! (g/mol)
      real , parameter:: amh2o =amo+2.0                   ! molecular wght of H2O ! (g/mol) 
      real , parameter:: amno=30.0061                     ! molecular wght of NO 
      real , parameter:: bz=1.3806505e-23                 ! Boltzmann constant 
      real , parameter:: wam_avgd=6.0221415e26            ! avogadro const 1/kmol
      real , parameter:: rbz=1./bz                        ! inverse 1/bz
      real , parameter:: rmo=wam_avgd/amo
      real , parameter:: rmo2=wam_avgd/amo2
      real , parameter:: rmo3=wam_avgd/amo3
      real , parameter:: rmh2o=wam_avgd/amh2o
      real , parameter:: rmn2=wam_avgd/amn2
!
!vay 2015: WARNING:  bz - Botzman & bz - magnetic (B)z 
!
      REAL, PARAMETER :: ELCH=1.602e-19
      real ,parameter :: PI = 3.141592653, Pi2=2.*PI

      real ,parameter :: Pid6 =PI/6., Pid2 =PI/2., Pid4 =PI/4.
      real ,parameter :: Pid3 =PI/3., Pid9 =PI/9., Pid12 =PI/12.
      real ,parameter :: Pid18 =PI/18.

      real ,parameter :: DTR =PI/180.0, R_2_D =1.0/DTR
      real ,parameter :: REARTH=6.370E06
      real, parameter :: YDAYS = 365.0, RYDAYS =1./YDAYS
!
      real, parameter :: vmr_nzero = 1.e-36, mmr_nzero =1.e-36 ! mixing ratios
      real, parameter :: con_nzero =vmr_nzero*1.e19            ! 1/m3
      real, parameter :: mmr_min = 1.e-32, mmr_max=0.999999
      real, parameter :: fac_lst = R_2_D/15.                   !lon_rad => lon_hrs
      real, parameter :: pi_24hr = pi2/24.
!
!SK   real            ::  prlog150(lev_wam)
      real            ::  prlog149(lev_wam)
      real            ::  amgm(lev_wam),amgms(lev_wam)  ! global mean wght of mix (g/mol)
!SK   real            ::  h2ora150(80),o3ra150(80)              
      real            ::  h2ora149(79),o3ra149(79)              
!
      real, allocatable::  pr_idea(:), prlog(:), ef(:)
      real, allocatable::  h2ora(:),o3ra(:)
      real, allocatable::  gg(:), prsilvl(:)
!SK2020Aug13
      real, allocatable, dimension(:):: gh2ort,gh2ovb,dg1rt,dg2rt,
     $     dg1vb,dg2vb,gdp,xx,wvmmrc,coeff
!SK
      integer nlev_h2o,nlevc_h2o,nlev_co2,k41,k71,k110,k105,k100,k43
      integer k91,k47,k64,k81,k87
!
!SK   data prlog150/-.010495013621173093,-.0047796645053569788,         
      data prlog149/-.010495013621173093,-.0047796645053569788,
     &.0017317939011674947,                                             
     &.0091445549523354423,.017575964483718530,.027156409259219756,     
     &.038029776798164390,.050354098813263921,.064301975566456532,      
     &.080060604331725002,.097831430661753094,.11782928094771801,       
     &.1402811398792534,.16542406580956714,.19350235130401269,          
     &.22476418567991183,.25945740055444533,.29782445285326098,         
     &.34009706723024435,.38649056296119455,.43719785635654262,         
     &.49238384410129205,.55218040859471984,.61668213110539583,         
     &.68594338857491133,.75997679704427235,.83875307597091064,         
     &.92220240072958426,1.0102172332720634,1.1026563113455261,         
     &1.1993493125965171,1.3001020446943199,1.4047022170280321,         
     &1.5129293855161694,1.6245648325694693,1.7393953508635152,         
     &1.8572172092097674,1.9778421006194884,2.1011027392385673,         
     &2.2268591758946630,2.3550060174351386,2.4854802051244675,         
     &2.6182709767607482,2.7534197208872264,2.8909811818384683,         
     &3.0309947994264324,3.1734952229335223,3.3185141840359855,         
     &3.4660806887940865,3.6162208681691572,3.7689579941351727,         
     &3.9243126000728270,4.0823023952198705,4.2429421890712113,         
     &4.4062440367083493,4.5722171074490712,4.7408678113152334,         
     &4.9121997598293738,5.0862136813095233,5.2629074813405223,         
     &5.4422762630064341,5.6243123514382578,5.8090052129405310,         
     &5.9963414712632250,6.1863048973029393,6.3788765414713984,         
     &6.5740346053768723,6.7717544276443897,6.9720085218050194,         
     &7.1747665967259380,7.3799955384809381,7.5876594664001917,         
     &7.7977196240960511,8.0101343615235372,8.2248592986929712,         
     &8.4418472650864640,8.6610481622066615,8.8824091352082579,         
     &9.1058744786331118,9.3313856279708016,9.5588812882688448,         
     &9.7882972917212427,10.019566564224711,10.252619320659370,         
     &10.487382934517129,10.723781889667228,10.961737871454984,         
     &11.201169705433793,11.441993457513469,11.684122340664617,         
     &11.927466717621803,12.171934093143912,12.417429143544323,         
     &12.663853787366328,12.911107059366048,13.159085134752051,         
     &13.407681405572704,13.656786420959016,13.906287867607862,         
     &14.156070558238182,14.406016545469104,14.656016536601980,         
     &14.906016520565826,15.156016549153117,15.406016561713120,         
     &15.656016540294088,15.906016534936020,16.156016568807406,         
     &16.406016534338949,16.656016529668964,16.906016577452895,         
     &17.156016561083050,17.406016546123016,17.656016537621376,         
     &17.906016506464592,18.156016518186942,18.406016541248878,         
     &18.656016561606052,18.906016537947128,19.156016514271940,         
     &19.406016513968229,19.656016519436953,19.906016540106812,         
     &20.156016505341348,20.406016517771079,20.656016529319292,         
     &20.906016501516998,21.156016508903946,21.406016525111486,         
     &21.656016521424860,21.906016510407873,22.156016517462234,         
     &22.406016507059238,22.656016506270586,22.906016547648477,         
     &23.156016547534154,23.406016516157738,23.656016508155140,         
     &23.906016513141179,24.156016519666711,24.406016497318937,         
     &24.656016492779738,24.906016503952380,25.156016485200560,         
     &25.406016484453687,25.656016491410533,25.906016498929535,         
     &26.156016525642059,26.406016533196180/
!SK  &26.156016525642059,26.406016533196180,27.231955945328760/
! 71-150 in levs=150
! 71-149 in levs=149
!SK   data h2ora150/4.15074772E-06,4.13699000E-06,4.11797890E-06,       
      data h2ora149/4.15074772E-06,4.13699000E-06,4.11797890E-06,
     &4.09487986E-06,                                                   
     &4.06858733E-06, 4.03597828E-06, 3.99688515E-06, 3.95067808E-06,   
     &3.89717454E-06, 3.83486354E-06, 3.76154928E-06, 3.67776509E-06,   
     &3.57952092E-06, 3.45696758E-06, 3.30616948E-06, 3.13086436E-06,   
     &2.91936568E-06, 2.64976784E-06, 2.33136751E-06, 1.97812350E-06,   
     &1.56715103E-06, 1.18281856E-06, 8.41511396E-07, 5.69260876E-07,   
     &3.88780697E-07, 2.50438515E-07,1.54300660E-07, 1.02009581E-07,    
     &6.65450034E-08, 4.17382808E-08, 2.82805186E-08, 2.01512556E-08,   
     &1.41564448E-08, 1.02806445E-08, 7.94408149E-09, 6.32637731E-09,   
     &5.12551203E-09, 4.27811892E-09, 3.70565449E-09, 3.31366890E-09,   
     &3.03512593E-09, 2.86004858E-09, 3.14079315E-09, 3.43411317E-09,   
     &3.75162719E-09, 4.09541203E-09, 4.46698364E-09, 4.86779007E-09,   
     &5.29913960E-09,5.76212751E-09, 6.25754557E-09, 6.78577268E-09,    
     &7.34664587E-09, 7.93931252E-09, 8.56206704E-09, 9.21217910E-09,   
     &9.88572497E-09, 1.05774394E-08, 1.12806111E-08, 1.19870504E-08,   
     &1.26871579E-08, 1.33701220E-08, 1.40242598E-08, 1.46374975E-08,   
     &1.51979607E-08, 1.56946171E-08, 1.61178886E-08, 1.64601425E-08,   
     &1.67159770E-08, 1.68822374E-08, 1.69577319E-08,1.69426375E-08,    
     &1.68375826E-08, 1.66423366E-08, 1.63538713E-08, 1.59631314E-08,   
     &1.54486221E-08, 1.47606491E-08, 1.37697900E-08/
!SK  &1.54486221E-08, 1.47606491E-08, 1.37697900E-08, 6.83803988E-09/  
!
! o3(71-150)
! o3(71-149)
!SK   data o3ra150/4.10541952E-06,3.47100766E-06,2.87068966E-06,        
      data o3ra149/4.10541952E-06,3.47100766E-06,2.87068966E-06,        
     &2.35683753E-06,                                                   
     &1.96476323E-06,1.68001584E-06,1.46059012E-06,1.28086944E-06,      
     & 1.12287103E-06,9.73440677E-07,8.31057093E-07,6.96823493E-07,
     & 5.70485075E-07,4.54900920E-07,3.51380290E-07,2.59055385E-07,
     & 1.83987938E-07,1.33985182E-07,9.93050813E-08,8.12517455E-08,
     & 1.04879335E-07,1.96984693E-07,3.40876799E-07,5.63920720E-07,
     & 8.83452184E-07,1.23309195E-06,1.61560931E-06,1.90510281E-06,
     & 2.00312741E-06,1.98334669E-06,1.75853471E-06,1.44161553E-06,
     & 1.11576928E-06,7.89776361E-07,5.25719302E-07,3.33307290E-07,
     & 1.90201852E-07,9.50490959E-08,4.25181927E-08,1.71517381E-08,
     & 6.31168787E-09,2.32353325E-09,2.00874504E-09,1.66279638E-09,
     & 1.36930561E-09,1.12419760E-09,9.19829659E-10,7.49814512E-10,
     & 6.08729657E-10,4.91976560E-10,3.95658450E-10,3.16475520E-10,
     & 2.51635148E-10,1.98775150E-10,1.55898314E-10,1.21316667E-10,
     & 9.36041570E-11,7.15566049E-11,5.41579312E-11,4.05517867E-11,
     & 3.00178145E-11,2.19518467E-11,1.58493829E-11,1.12917456E-11,
     & 7.93434889E-12,5.49657616E-12,3.75284443E-12,2.52454277E-12,
     & 1.67265129E-12,1.09096239E-12,6.99914181E-13,4.41092526E-13,
     & 2.72463151E-13,1.64366989E-13,9.62680762E-14,5.41996795E-14,
     & 2.88221148E-14,1.39894852E-14,5.72118432E-15/
!SK  & 2.88221148E-14,1.39894852E-14,5.72118432E-15,4.70438733E-16/
!
!
      end module idea_composition
!ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
!     contains
!hmhj subroutine idea_composition_init(levs,ak,bk) 
      subroutine idea_composition_init(levs,plyr) 
!-------------------------------------------------------------------------
! get O O2 N2 composition in idea_composition
!-------------------------------------------------------------------------
      use idea_composition
!     use module_physics_driver, only : is_master      !SK
      implicit none
! Argument
      integer, intent(in) :: levs             ! number of pressure levels
      real, intent(in)    :: plyr(levs)
!hmhj real, intent(in)    :: ak(levs+1),bk(levs+1) ! hyb levels
! local
      integer k
!     logical, parameter :: is_master = .true.
      logical :: is_master
!
      is_master = mpi_me == mpi_master
!SK   if (.not.allocated(pr_idea)) allocate (pr_idea(levs))
!SK   if (.not.allocated(pr_idea)) then
!SK     allocate (pr_idea(levs))
!       if (is_master) print *,' plyr idea_composition_init ',
!    &                (plyr(k),k=1,levs)
        do k=1,levs
          pr_idea(k) = plyr(k)/100.    ! mb
        enddo
!SK   endif
!       if (is_master) print *,' pr_idea idea_composition_init ',
!    &                (pr_idea(k),k=1,levs)
!
!SK   allocate (prlog(levs))
!SK   if (.not.allocated(prlog)) allocate (prlog(levs))
!
      do k=1,levs
!       prlog  (k) = log(1000./pr_idea(k))    ! replaces "-" log to '+log"
!SK     prlog  (k) = log(1013./pr_idea(k))    ! replaces "-" log to '+log"
        prlog  (k) = log(pr_idea(1)/pr_idea(k))    !SK2020Sep24
!       if (is_master) then
!        print *,' idea_composition_init: k pr_idea prlog ',k,
!    &               pr_idea(k),prlog(k)
!       endif
      enddo
      if (is_master) then
       write(*,1001) (k, prlog(k),k=1,levs)
1001   format(1x,'idea_composition_init: k prlog(k)'/
     &       (1x,i3,1x,e14.7))
      endif
!
!SK   allocate (h2ora(levs))
!SK   allocate (o3ra(levs))
!SK   if (.not.allocated(h2ora)) allocate (h2ora(levs))
!SK   if (.not.allocated(o3ra))  allocate (o3ra(levs))
!
! init h2o rad 
!SK     if(levs.eq.150) then
        if(levs.eq.149) then
          k41=40     !41
          k110=109   !110
          k71=70     !71
          k105=104   !105
          k100=99    !100
! co2
          k43=42     !43
! ion
          k91=90     !91
! merge
          k47=46     !47
          k64=63     !64
          k81=80     !81
          k87=86     !87
        else
          k71=levs
          k81=levs
          k87=levs
          k91=levs
          k100=levs
          k105=levs
          k110=levs
          do k=3,levs-2
!         if(prlog(k).ge.prlog150(41).and.prlog(k-1).lt.prlog150(41))   
          if(prlog(k).ge.prlog149(41).and.prlog(k-1).lt.prlog149(41))   
     &       k41=k
!         if(prlog(k).ge.prlog150(71).and.prlog(k-1).lt.prlog150(71))   
          if(prlog(k).ge.prlog149(71).and.prlog(k-1).lt.prlog149(71))   
     &       k71=k
!         if(prlog(k).le.prlog150(110).and.prlog(k+1).gt.prlog150(110)) 
          if(prlog(k).le.prlog149(110).and.prlog(k+1).gt.prlog149(110)) 
     &       k110=k
!         if(prlog(k).ge.prlog150(100).and.prlog(k-1).lt.prlog150(100)) 
          if(prlog(k).ge.prlog149(100).and.prlog(k-1).lt.prlog149(100)) 
     &       k100=k
!         if(prlog(k).le.prlog150(105).and.prlog(k+1).gt.prlog150(105)) 
          if(prlog(k).le.prlog149(105).and.prlog(k+1).gt.prlog149(105)) 
     &       k105=k
!         if(prlog(k).ge.prlog150(43).and.prlog(k-1).lt.prlog150(43))   
          if(prlog(k).ge.prlog149(43).and.prlog(k-1).lt.prlog149(43))   
     &       k43=k
!         if(prlog(k).ge.prlog150(91).and.prlog(k-1).lt.prlog150(91))   
          if(prlog(k).ge.prlog149(91).and.prlog(k-1).lt.prlog149(91))   
     &       k91=k
!         if(prlog(k).ge.prlog150(47).and.prlog(k-1).lt.prlog150(47))   
          if(prlog(k).ge.prlog149(47).and.prlog(k-1).lt.prlog149(47))   
     &       k47=k
!         if(prlog(k).ge.prlog150(64).and.prlog(k-1).lt.prlog150(64))   
          if(prlog(k).ge.prlog149(64).and.prlog(k-1).lt.prlog149(64))   
     &       k64=k
!         if(prlog(k).ge.prlog150(81).and.prlog(k-1).lt.prlog150(81))   
          if(prlog(k).ge.prlog149(81).and.prlog(k-1).lt.prlog149(81))   
     &       k81=k
!         if(prlog(k).ge.prlog150(87).and.prlog(k-1).lt.prlog150(87))   
          if(prlog(k).ge.prlog149(87).and.prlog(k-1).lt.prlog149(87))   
     &       k87=k
          enddo
        endif
          nlev_h2o=k110-k41+1
          nlevc_h2o=levs-k71+1
          nlev_co2=levs-k43+1
!SK   if(levs.eq.150) then
      if(levs.eq.149) then
!SK       h2ora(k71:levs)=h2ora150
          h2ora(k71:levs)=h2ora149
          h2ora(1:k71-1)=0.
!SK       o3ra(k71:levs)=o3ra150
          o3ra(k71:levs)=o3ra149
          o3ra(1:k71-1)=0.
      else
!SK       call idea_interp(h2ora150,71,150,80,h2ora,levs)
          call idea_interp(h2ora149,71,149,80,h2ora,levs)
!SK       call idea_interp(o3ra150,71,150,80,o3ra,levs)
          call idea_interp(o3ra149,71,149,80,o3ra,levs)
      endif
      return
      end subroutine idea_composition_init
!ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine idea_interp(ain,nps,npn,np,aout,levs)
      use idea_composition 
      implicit none
      real ain(np),aout(levs),z(np),z1(levs),dz
      integer nps,npn,np,levs,kref,k,i
!SK   z(1:np)=prlog150(nps:npn)
      z(1:np)=prlog149(nps:npn)
      z1=prlog
      do k=1,levs
      kref=0
      do i=1,np-1
      if(z1(k).ge.z(i).and.z1(k).le.z(i+1)) then
      kref=i
      dz=(z1(k)-z(i))/(z(i+1)-z(i))
      endif
      enddo
      if(kref.ne.0) aout(k)=dz*ain(kref+1)+(1.-dz)*ain(kref)
      enddo
      return
      end subroutine idea_interp
