#!/usr/bin/env gosh

;;(load "~/apl/at/gfora.scm")

(define device_path&name "../m3")
;;(define device_name device_path&name)
(define device_name "m3")

(define width 1)
(define temp 300)
(define freq 1e-3)

(define vdstep 0.1)

(define vdrains (list 0 1))
(define vgates (list 0 1))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define dir-output
  #`"output")
(define dir-dev
  #`",|dir-output|/,|device_name|")

(define dir-structure
  #`",|dir-dev|/structure")
(define (strfile-dev)
  #`",|device_path&name|.str")

;>>>>>>>>>>>>>>>>>>>
(define dir-idvds
  #`",|dir-dev|/idvds")
(define (logfile-idvd vg) ; for each vg, idvd graph is calculated.
  #`",|dir-idvds|/idvds_vg,|vg|.log")
(define (outfile-idvd vg vd) ; file_vg_vd
  #`",|dir-structure|/trench_vg,|vg|_vd,|vd|.str")


(define dir-idvgs
  #`",|dir-dev|/idvgs")
(define (logfile-idvg vd) ; for each vd, idvg graph is calculated.
  #`",|dir-idvgs|/idvgs_vd,|vd|.log")
(define (outfile-idvg vd vg) ; file_vg_vd
  #`",|dir-structure|/trench_vd,|vd|_vg,|vg|.str")
;<<<<<<<<<<<<<<<<<<

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-block (calc-idvg vdrains vgates)
  (% system mkdir -p $dir-idvgs)
  (% system mkdir -p $dir-structure)  
  (local ((vgstart (car vgates))
          (vgmains (cdr vgates)))
         
         (loop vd vdrains
               (% solve vgate= $vgstart name=gate) ; for initialization as to gate
               (% solve vdrain= $vd name=drain)
               (% save outf= (outfile-idvg vd vgstart))
               
               (% log outf= (logfile-idvg vd) j.electron j.hole) ; log start
               (loop vg vgates
                     (% solve prev vfinal= $vg name=gate vstep= $vdstep)
                     (% save outf= (outfile-idvg vd vg)))
               (% log close))))

(define-block (calc-idvd vgates vdrains)
  (% system mkdir -p $dir-idvds)
  (% system mkdir -p $dir-structure)  
  (local ((vdstart (car vdrains))
          (vdmains (cdr vdrains)))
         
         (loop vg vgates
               (% solve vdrain= $vdstart name=drain) ; for initialization as to drain
               (% solve vgate= $vg name=gate)
               (% save outf= (outfile-idvd vg vdstart))
               
               (% log outf= (logfile-idvd vg) j.electron j.hole) ; log start
               (loop vd vdmains
                     (% solve prev vfinal= $vd name=drain vstep= $vdstep)
                     (% save outf= (outfile-idvd vg vd)))
               (% log close))))

(<main>
 (% go atlas)
 (% mesh inf= (strfile-dev) width= $width)
 (% contact name=gate n.poly)
 (% models conmob fldmob consrh auger bgn print temp= 300)
 (% solve init)
 (% solve prev)

 (% output e.mobility h.mobility ey.velocity hy.velocity charge)
 (>> ox.charge e.lines flowlines j.disp j.drift j.diffusion  con.band val.band)
 
 (% method newton carriers=2 trap maxtrap=15)

 ;; (if (eq? jobtype 'idvd)
 ;;     (calc-idvg vgates vdrains)
 ;;     (calc-idvd vdrains vgates))
 
  (calc-idvg vdrains vgates)
  (calc-idvd vgates vdrains)
 
 (% quit))
