MODULE service_functions

!This module contains functions, that are often used and not necessarily related
!to the emulator, such as matrix inversion...

IMPLICIT NONE

contains

FUNCTION rmse(vector1,vector2) result(out)
  real :: vector1(:),vector2(:)
  real :: out
  integer :: length
  length=size(vector1)
  out=sqrt(sum((vector1(1:length/2)-vector2(1:length/2))**2)/length*2)
  !we calculate the error just fro one half of the results!!!!!!!!!!!
  !done only for my paper case
end function rmse

FUNCTION expo_mat(matrix,delta_t,m) result(out)
INTEGER :: i,j
INTEGER :: m
real :: delta_t,matrix(m,m),out(m,m)
double precision,ALLOCATABLE :: wsp(:)
INTEGER :: lwsp,iexph, ns, iflag, ipiv(m)
lwsp=4*m*m+6+6
ipiv=0
ALLOCATE(wsp(lwsp))
wsp=0
CALL DGPADM(6,m,1D0,dble(matrix),m,wsp,lwsp,ipiv,iexph,&
ns,iflag)
out=0
DO i=1,m
  DO j=1,m
    out(j,i) = real(wsp(iexph+(i-1)*m+j-1))
  END DO
END DO
END FUNCTION expo_mat

FUNCTION inv_mat(matrix) result(out)
INTEGER :: i,m
real :: matrix(:,:),out(size(matrix,1),size(matrix,2))
INTEGER,ALLOCATABLE :: ipiv(:)
real,ALLOCATABLE :: work(:)
INTEGER :: info=0
m=size(matrix,1)
out = matrix
i =INT(m)
IF (ALLOCATED(work)) THEN
 DEALLOCATE(work)
ENDIF
ALLOCATE(work(i))
work=0
IF (ALLOCATED(ipiv)) THEN
 DEALLOCATE(ipiv)
ENDIF
ALLOCATE(ipiv(i))
ipiv=0

CALL sgetrf(i,i,out,i,ipiv,work,info)
IF ( info .NE. 0 ) THEN
 write(*,*) 'not OK'
END IF
CALL sgetri(i,out,i,ipiv,work,i,info)
IF ( info .NE. 0 ) THEN
 write(*,*) 'not OK'
END IF

END FUNCTION inv_mat


function rep_array(array,times) result(out)
integer :: i,times
real :: array(:),out(size(array)*times)
do i=1,times
  out((i-1)*size(array)+1:i*size(array))=array
end do
end function rep_array

SUBROUTINE write_output(matrix,path)
INTEGER :: i,j
CHARACTER(LEN=*) :: path
real :: matrix(:,:)
OPEN(88,FILE=path)
DO i=1,size(matrix, dim=1)
  do j=1,size(matrix, dim=2)
      WRITE (88,"(f16.4,A)",advance='no') matrix(i,j)
    end do 
    write(88,*) ""
END DO
CLOSE(88)
END SUBROUTINE


!----------------------------------------------------------------------|
      subroutine DGPADM( ideg,m,t,H,ldh,wsp,lwsp,ipiv,iexph,ns,iflag )

      implicit none
      integer ideg, m, ldh, lwsp, iexph, ns, iflag, ipiv(m)
      double precision t, H(ldh,m), wsp(lwsp)

!-----Purpose----------------------------------------------------------|
!
!     Computes exp(t*H), the matrix exponential of a general matrix in
!     full, using the irreducible rational Pade approximation to the 
!     exponential function exp(x) = r(x) = (+/-)( I + 2*(q(x)/p(x)) ),
!     combined with scaling-and-squaring.
!
!-----Arguments--------------------------------------------------------|
!
!     ideg      : (input) the degre of the diagonal Pade to be used.
!                 a value of 6 is generally satisfactory.
!
!     m         : (input) order of H.
!
!     H(ldh,m)  : (input) argument matrix.
!
!     t         : (input) time-scale (can be < 0).
!                  
!     wsp(lwsp) : (workspace/output) lwsp .ge. 4*m*m+ideg+1.
!
!     ipiv(m)   : (workspace)
!
!>>>> iexph     : (output) number such that wsp(iexph) points to exp(tH)
!                 i.e., exp(tH) is located at wsp(iexph ... iexph+m*m-1)
!                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
!                 NOTE: if the routine was called with wsp(iptr), 
!                       then exp(tH) will start at wsp(iptr+iexph-1).
!
!     ns        : (output) number of scaling-squaring used.
!
!     iflag     : (output) exit flag.
!                      0 - no problem
!                     <0 - problem
!
!----------------------------------------------------------------------|
!     Roger B. Sidje (rbs@maths.uq.edu.au)
!     EXPOKIT: Software Package for Computing Matrix Exponentials.
!     ACM - Transactions On Mathematical Software, 24(1):130-156, 1998
!----------------------------------------------------------------------|
!
      integer mm,i,j,k,ih2,ip,iq,iused,ifree,iodd,icoef,iput,iget
      double precision hnorm,scale,scale2,cp,cq

      intrinsic INT,ABS,DBLE,LOG,MAX

!---  check restrictions on input parameters ...
      mm = m*m
      iflag = 0
      if ( ldh.lt.m ) iflag = -1
      if ( lwsp.lt.4*mm+ideg+1 ) iflag = -2
      if ( iflag.ne.0 ) stop 'bad sizes (in input of DGPADM)'
!
!---  initialise pointers ...
!
      icoef = 1
      ih2 = icoef + (ideg+1)
      ip  = ih2 + mm
      iq  = ip + mm
      ifree = iq + mm
!
!---  scaling: seek ns such that ||t*H/2^ns|| < 1/2; 
!     and set scale = t/2^ns ...
!
      do i = 1,m
         wsp(i) = 0.0d0
      enddo
      do j = 1,m
         do i = 1,m
            wsp(i) = wsp(i) + ABS( H(i,j) )
         enddo
      enddo
      hnorm = 0.0d0
      do i = 1,m
         hnorm = MAX( hnorm,wsp(i) )
      enddo
      hnorm = ABS( t*hnorm )
      if ( hnorm.eq.0.0d0 ) stop 'Error - null H in input of DGPADM.'
      ns = MAX( 0,INT(LOG(hnorm)/LOG(2.0d0))+2 )
      scale = t / DBLE(2**ns)
      scale2 = scale*scale
!
!---  compute Pade coefficients ...
!
      i = ideg+1
      j = 2*ideg+1
      wsp(icoef) = 1.0d0
      do k = 1,ideg
         wsp(icoef+k) = (wsp(icoef+k-1)*DBLE( i-k ))/DBLE( k*(j-k) )
      enddo
!
!---  H2 = scale2*H*H ...
!
      call DGEMM( 'n','n',m,m,m,scale2,H,ldh,H,ldh,0.0d0,wsp(ih2),m )
!
!---  initialize p (numerator) and q (denominator) ...
!
      cp = wsp(icoef+ideg-1)
      cq = wsp(icoef+ideg)
      do j = 1,m
         do i = 1,m
            wsp(ip + (j-1)*m + i-1) = 0.0d0
            wsp(iq + (j-1)*m + i-1) = 0.0d0
         enddo
         wsp(ip + (j-1)*(m+1)) = cp
         wsp(iq + (j-1)*(m+1)) = cq
      enddo
!
!---  Apply Horner rule ...
!
      iodd = 1
      k = ideg - 1
 100  continue
      iused = iodd*iq + (1-iodd)*ip
      call DGEMM( 'n','n',m,m,m, 1.0d0,wsp(iused),m,&
                  wsp(ih2),m, 0.0d0,wsp(ifree),m )
      do j = 1,m
         wsp(ifree+(j-1)*(m+1)) = wsp(ifree+(j-1)*(m+1))+wsp(icoef+k-1)
      enddo
      ip = (1-iodd)*ifree + iodd*ip
      iq = iodd*ifree + (1-iodd)*iq
      ifree = iused
      iodd = 1-iodd
      k = k-1
      if ( k.gt.0 )  goto 100
!
!---  Obtain (+/-)(I + 2*(p\q)) ...
!
      if ( iodd .eq. 1 ) then
         call DGEMM( 'n','n',m,m,m, scale,wsp(iq),m,&
                     H,ldh, 0.0d0,wsp(ifree),m )
         iq = ifree
      else
         call DGEMM( 'n','n',m,m,m, scale,wsp(ip),m,&
                     H,ldh, 0.0d0,wsp(ifree),m )
         ip = ifree
      endif
      call DAXPY( mm, -1.0d0,wsp(ip),1, wsp(iq),1 )
      call DGESV( m,m, wsp(iq),m, ipiv, wsp(ip),m, iflag )
      if ( iflag.ne.0 ) stop 'Problem in DGESV (within DGPADM)'
      call DSCAL( mm, 2.0d0, wsp(ip), 1 )
      do j = 1,m
         wsp(ip+(j-1)*(m+1)) = wsp(ip+(j-1)*(m+1)) + 1.0d0
      enddo
      iput = ip
      if ( ns.eq.0 .and. iodd.eq.1 ) then
         call DSCAL( mm, -1.0d0, wsp(ip), 1 )
         goto 200
      endif
!
!--   squaring : exp(t*H) = (exp(t*H))^(2^ns) ...
!
      iodd = 1
      do k = 1,ns
         iget = iodd*ip + (1-iodd)*iq
         iput = (1-iodd)*ip + iodd*iq
         call DGEMM( 'n','n',m,m,m, 1.0d0,wsp(iget),m, wsp(iget),m,&
                     0.0d0,wsp(iput),m )
         iodd = 1-iodd
      enddo
 200  continue
      iexph = iput
      END
!----------------------------------------------------------------------|

!functions related to C-type emulator


SUBROUTINE write_vector(vector,path,time)
IMPLICIT NONE
INTEGER :: i,j,time
CHARACTER(LEN=*) :: path
real :: vector(:)
OPEN(88,FILE=path)
do j=1,size(vector)/time
  DO i=1,time
       WRITE (88,"(f16.4,A)",advance='no') vector((j-1)*time+i)
  END DO
  write(88,*) ""
end do
CLOSE(88)
END SUBROUTINE

SUBROUTINE write_int_vector(vector,path,time)
IMPLICIT NONE
INTEGER :: i,j,time
CHARACTER(LEN=*) :: path
INTEGER :: vector(:)
OPEN(88,FILE=path,position='append')
do j=1,size(vector)/time
  DO i=1,time
       WRITE (88,"(i16,A)",advance='no') vector((j-1)*time+i)
  END DO
  write(88,*) ""
end do
CLOSE(88)
END SUBROUTINE

FUNCTION mat_to_vec(matrix) result(vector)
    IMPLICIT NONE
    real,ALLOCATABLE :: vector(:)
    real :: matrix(:,:)

    IF (ALLOCATED(vector)) THEN
     DEALLOCATE(vector)
    ENDIF
    ALLOCATE(vector(size(matrix,1)))
    vector=0

    vector=matrix(:,1)

END FUNCTION mat_to_vec

FUNCTION double_scalar(non_scalar) result(out)
    IMPLICIT NONE
    real :: out
    real :: non_scalar(1,1)

    out=non_scalar(1,1)

END FUNCTION double_scalar

FUNCTION scalar_matrix(scalar) result(out)
    IMPLICIT NONE
    real :: out(1,1)
    real :: scalar

    out(1,1)=scalar

END FUNCTION scalar_matrix


!the two following functions are necesarry for simann

function ranmar()
real ranmar
real U(97), C, CD, CM
integer I97, J97
common /raset1/ U, C, CD, CM, I97, J97
real uni
   uni = U(I97) - U(J97)
   if( uni .lt. 0.0 ) uni = uni + 1.0
   U(I97) = uni
   I97 = I97 - 1
   if(I97 .eq. 0) I97 = 97
   J97 = J97 - 1
   if(J97 .eq. 0) J97 = 97
   C = C - CD
   if( C .lt. 0.0 ) C = C + CM
   uni = uni - C
   if( uni .lt. 0.0 ) uni = uni + 1.0
   RANMAR = uni
return
END function

function seedgen(pid)
    use iso_fortran_env
    implicit none
    integer(kind=int64) :: seedgen
    integer, intent(IN) :: pid
    integer :: s

    call system_clock(s)
    seedgen = abs( mod((s*181)*((pid-83)*359), 104729) ) 
end function seedgen


END MODULE