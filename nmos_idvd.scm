#!/usr/bin/env gosh

(use srfi-42)
(use slib)
(require 'format)
(load "~/apl/at/gfora.scm")
(load "~/apl/at/tools.scm")

;;(define device-path&name-list (list "../m3"))
;;(define device_name device_path&name)
;;(define device-name "m3")

(define device-path&name-list (map remove-str-extension *argv*))

(define width 1)
(define temp 300)
(define freq 1e-3)

(define vstep 0.05)
(define coarse-vstep 0.1)

(define jobtype-list (list 'idvd 'idvg))
(define vdrains '(0 1 2 3 4 5))
(define vgates '(0 1 2 3 4 5))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; base condition
(define vd-conditions (list 0.05)) ; don't use in idvd
(define vg-conditions (list 0.05)) ; don't use in idvg
(define vbs-conditions (list -0.5 0.0 0.5 1.0))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-atlas-block (condition-initialize vd vg vbs)
  (% solve vdrain= $vd name=drain) ; for initialization as to drain
  (% solve vgate= $vg name=gate)
  (% solve vsubstrate= $vbs))

(define-atlas-block (do-job jobtype vdrains vgates strfile coarse-vstep vstep)
  (cond ((eq? jobtype 'idvd)
         (list
          (% solve vfinal= (car vdrains) name=drain vstep= $coarse-vstep)
          (loop vd vdrains
                (% solve prev vfinal= $vd name=drain vstep= $vstep)
                (% save outf= #`",|strfile|_vd,|vd|.str"))))
        ((eq? jobtype 'idvg)
         (list
          (% solve vfinal= (car vgates) name=gate vstep= $coarse-vstep)
          (loop vg vgates
                (% solve prev vfinal= $vg name=gate vstep= $vstep)
                (% save outf= #`",|strfile|_vd,|vd|_vg,|vg|.str"))))))

(do-ec
 (: device-path&name device-path&name-list)
 (: jobtype jobtype-list)
 (: vd vd-conditions)
 (: vg vg-conditions)
 (: vbs vbs-conditions)
 
 (let* ((device-name (sys-basename device-path&name))
        (basename device-name)
        (basename (add-variables-name basename "_vd" vd vd-conditions))
        (basename (add-variables-name basename "_vg" vg vg-conditions))
        (basename (add-variables-name basename "_vbs" vbs vbs-conditions)))

     (let ((logfile #`"log/,|basename|")
           (strfile #`"str/,|basename|"))
       (<main>
        (<start> go atlas)
        (% system mkdir -p log)
        (% system mkdir -p str)
      
        (% mesh inf= $device-path&name width= $width)
        (% contact name=gate n.poly)
        (% models conmob fldmob consrh auger bgn print temp= 300)
        (% solve init)
        (% solve prev)

        (% output e.mobility h.mobility ey.velocity hy.velocity charge)
        (>> ox.charge e.lines flowlines j.disp j.drift j.diffusion  con.band val.band)
 
        (% method newton carriers=2 trap maxtrap=15)

        (!condition-initialize vd vg vbs)
        (% save outf= #`",|strfile|_init.str")
        (% log outf= #`",|logfile|.log")
        
        (!do-job jobtype vdrains vgates strfile coarse-vstep vstep)
        
        (% log close)
        (% quit)))))
