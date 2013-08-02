#!/usr/bin/env gosh

(use srfi-42)
(use slib)
(require 'format)
(load "~/apl/at/gfora.scm")
(load "~/apl/at/tools.scm")

(define device-path&name "../m3")
;;(define device_name device_path&name)
(define device-name "m3")

(define width 1)
(define temp 300)
(define freq 1e-3)

(define vstep 0.05)
(define coarse-vstep 0.1)
(define vdrains (list 0 1 2 3 4 5))
(define vgates (list 0 1 2 3 4 5))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define base-dir "F")
(define jobtype-list (list 'idvd 'idvg))
(define vdrains '(0 1 2 3 4 5))
(define vgates '(0 1 2 3 4 5))

(define vd-conditions (list 0.05))
(define vg-conditions (list 0))
(define vbs-conditions (list -1.0 -0.5 0.0 0.5 1.0))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (initialize vd vg vbs)
  (% solve vdrain= $vd name=drain) ; for initialization as to drain
  (% solve vgate= $vg name=gate)
  (% solve vsubstrate= $vbs))

(do-ec
 (: jobtype jobtype-list)
 (: vd vd-conditions)
 (: vg vg-conditions)
 (: vbs vbs-conditions)
 
 (let* ((basedir "")
        (basedir (add-variables-name basedir "/vd" vd vd-conditions))
        (basedir (add-variables-name basedir "/vg" vg vg-conditions))
        (basedir (add-variables-name basedir "/vbs" vbs vbs-conditions)))
   (sys-system #`"mkdir -p out,|basedir|")
   (sys-system #`"mkdir -p str,|basedir|")
     (<main>
      (<start> go atlas)
      (% mesh inf= $device-path&name width= $width)
      (% contact name=gate n.poly)
      (% models conmob fldmob consrh auger bgn print temp= 300)
      (% solve init)
      (% solve prev)

      (% output e.mobility h.mobility ey.velocity hy.velocity charge)
      (>> ox.charge e.lines flowlines j.disp j.drift j.diffusion  con.band val.band)
 
      (% method newton carriers=2 trap maxtrap=15)

      (initialize vd vg vbs)
      (% save outf= #`"str,|basedir|/init.str")
      (% log outf= #`"log,|basedir|/result.log")
      (cond ((eq? jobtype 'idvd)
             (list
              (% solve vfinal= (car vdrains) name=drain vstep= $coarse-vstep)
              (loop vd vdrains
                    (% solve prev vfinal= $vd name=drain vstep= $vstep)
                    (% save outf= #`"str,|basedir|/vd,|vd|.str"))))
            ((eq? jobtype 'idvg)
             (list
              (% solve vfinal= (car vgates) name=gate vstep= $coarse-vstep)
              (loop vg vgates
                    (% solve prev vfinal= $vg name=gate vstep= $vstep)
                    (% save outf= #`"str,|basedir|/vd,|vd|_vg,|vg|.str")))))
      (% log close)
      (% quit))))
