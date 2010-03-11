
;; MiniPerl6 Lisp runtime
;;
;; Author: Flavio Soibelmann Glock <fglock@gmail.com>
;;
;; Copyright 2009 by Flavio Soibelmann Glock and others.
;; 
;; This program is free software; you can redistribute it and/or modify it
;; under the same terms as Perl itself.
;; 
;; See <http://www.perl.com/perl/misc/Artistic.html>

(defpackage mp-Main
  (:use common-lisp)
  (:export 
        #:sv-eq #:sv-bool #:sv-substr #:sv-say #:sv-print #:sv-index 
        #:sv-and #:sv-or #:sv-perl #:sv-scalar #:sv-string #:sv-undef
        #:sv-defined))
(in-package mp-Main)

(setf COMMON-LISP-USER::*posix-argv* (cdr COMMON-LISP-USER::*posix-argv*))

;; "undef"

(if (not (ignore-errors (find-class 'mp-Undef)))
  (defclass mp-Undef () ()))
(let (x)
  (setq x (make-instance 'mp-Undef))
  (defun proto-mp-Undef () x)
  (defun sv-undef () x))

;; core functions

(if (not (ignore-errors (find-method 'sv-defined () ())))
  (defgeneric sv-defined (x)
      (:documentation "check if a value is defined")))
(defmethod sv-defined (x) t)
(defmethod sv-defined ((x mp-Undef)) nil)

(defun sv-say (l)
  (format t "~{~a~}~%" l))

(defun sv-print (l)
  (format t "~{~a~}" l))

(defun sv-substr (s start count) 
  (let ((l1 (length s)) (l2 (+ start count)))
  (or (ignore-errors (subseq s start (if (> l2 l1) l1 l2)))
      "")))

(defun sv-index (s substr &optional start) 
  (let ((l1 (search substr s))) 
    (if l1 l1 -1)))

(if (not (ignore-errors (find-method 'sv-string () ())))
  (defgeneric sv-string (x)
      (:documentation "stringify values")))
(defmethod sv-string (x) x)
(defmethod sv-string ((x number)) (format nil "~a" x))
(defmethod sv-string ((x mp-Undef)) "")

(if (not (ignore-errors (find-method 'sv-eq () ())))
  (defgeneric sv-eq (x y)
      (:documentation "compare string values")))
;; (defmethod sv-eq (x y) (eql x y))
(defmethod sv-eq (x y)                   (equal (sv-string x) (sv-string y)))
(defmethod sv-eq (x (y string))          (equal (sv-string x) y))
(defmethod sv-eq ((x string) (y string)) (equal x y))
(defmethod sv-eq ((x string) (y number)) (equal x (format nil "~a" y)))
(defmethod sv-eq ((x number) (y string)) (equal (format nil "~a" x) y))

(if (not (ignore-errors (find-method 'sv-eq-int () ())))
  (defgeneric sv-eq-int (x y)
      (:documentation "compare int values")))
;; (defmethod sv-eq (x y) (eql x y))
(defmethod sv-eq-int (x y)                   (eql x y))
(defmethod sv-eq-int (x (y string))          (eql x (parse-integer y)))
(defmethod sv-eq-int ((x string) (y string)) (eql (parse-integer x) (parse-integer y)))
(defmethod sv-eq-int ((x string) (y number)) (eql (parse-integer x) y))
(defmethod sv-eq-int ((x number) (y string)) (eql x (parse-integer y)))
(defmethod sv-eq-int ((x number) (y number)) (eql x y))

(if (not (ignore-errors (find-method 'sv-bool () ())))
  (defgeneric sv-bool (self)
      (:documentation "get a bool value")))
(defmethod sv-bool (x) x)
(defmethod sv-bool ((x mp-Undef)) nil)
(defmethod sv-bool ((x number)) (not (eql x 0)))
(defmethod sv-bool ((x string)) (and (not (equal x "")) (not (equal x "0"))))

(defmacro sv-and (x y)
 `(and (sv-bool ,x) (sv-bool ,y)))

;; (if (not (ignore-errors (find-method 'sv-and () ())))
;;   (defgeneric sv-and (x y)
;;       (:documentation "and")))
;; (defmethod sv-and (x y) (and (sv-bool x) (sv-bool y)))

(defmacro sv-or (x y)
 `(or (sv-bool ,x) (sv-bool ,y)))

;; (if (not (ignore-errors (find-method 'sv-or () ())))
;;   (defgeneric sv-or (x y)
;;       (:documentation "or")))
;; (defmethod sv-or (x y) (or (sv-bool x) (sv-bool y)))

(if (not (ignore-errors (find-method 'sv-perl () ())))
  (defgeneric sv-perl (self)
      (:documentation "data dumper")))
(defmethod sv-perl (x)          (format nil "~A" x))
(defmethod sv-perl ((x string)) (format nil "~{~a~}" (list "'" (sv-perl_escape_string x) "'")))
(defmethod sv-perl ((x list))   (format nil "~{~a~}" (list "[ " (sv-join (mapcar #'sv-perl x) ", ") " ]" )))
(defmethod sv-perl ((x mp-Undef)) "undef")
(defmethod sv-perl ((x hash-table))
   (format nil "~{~a~}" (list
        "{ " 
        (let (l) 
            (maphash #'(lambda (key val) (push (format nil "~A => ~A" (sv-perl key) (sv-perl val)) l)) x) 
            (sv-join l ", " ))
        " }" )))

(if (not (ignore-errors (find-method 'sv-scalar () ())))
  (defgeneric sv-scalar (self)
      (:documentation "get a scalar value")))
(defmethod sv-scalar (x) x)


;; Array

    ;; (setf (slot-value m 'array) (make-array 10 :adjustable 1))))

(defpackage mp-array
  (:use common-lisp mp-Main))
;; (in-package mp-array)
(if (not (ignore-errors (find-class 'mp-array)))
  (defclass mp-array () ()))

(let (x) 
  (setq x (make-instance 'mp-array))
  (defun proto-mp-array () x))
;; has $.array
(let ((new-slots (list (list :name 'sv-array
  :readers '(sv-array)
  :writers '((setf sv-array))
  :initform '(sv-undef)
  :initfunction (constantly (sv-undef))))))
(dolist (slot-defn (sb-mop:class-direct-slots (find-class 'mp-array)))
(push (list :name (sb-mop:slot-definition-name slot-defn)
  :readers (sb-mop:slot-definition-readers slot-defn)
  :writers (sb-mop:slot-definition-writers slot-defn)
  :initform (sb-mop:slot-definition-initform slot-defn)
  :initfunction (sb-mop:slot-definition-initfunction slot-defn))
new-slots))
(sb-mop:ensure-class 'mp-array :direct-slots new-slots))

;; method index
(if (not (ignore-errors (find-method 'sv-index () ())))
  (defgeneric sv-index (sv-self &optional sv-ix)
      (:documentation "a method")))
(defmethod sv-index ((sv-self mp-array) &optional sv-ix)
  (block mp6-function
    (progn (elt sv-array sv-ix))))

;; method push
(if (not (ignore-errors (find-method 'sv-push () ())))
  (defgeneric sv-push (sv-self &optional sv-o)
      (:documentation "a method")))
(defmethod sv-push ((sv-self mp-array) &optional sv-o)
  (block mp6-function
    (progn (sv-push sv-array sv-o))))

;; method unshift
(if (not (ignore-errors (find-method 'sv-unshift () ())))
  (defgeneric sv-unshift (sv-self &optional sv-o)
      (:documentation "a method")))
(defmethod sv-unshift ((sv-self mp-array) &optional sv-o)
  (block mp6-function
    (progn (sv-unshift sv-array sv-o))))

;; method pop
(if (not (ignore-errors (find-method 'sv-pop () ())))
  (defgeneric sv-pop (sv-self)
      (:documentation "a method")))
(defmethod sv-pop ((sv-self mp-array))
  (block mp6-function
    (progn (sv-pop sv-array))))

;; method shift
(if (not (ignore-errors (find-method 'sv-shift () ())))
  (defgeneric sv-shift (sv-self)
      (:documentation "a method")))
(defmethod sv-shift ((sv-self mp-array))
  (block mp6-function
    (progn (sv-shift sv-array))))

(defmethod sv-perl ((self mp-array))
  (mp-Main::sv-lisp_dump_object "::array" (list (let ((m (make-instance 'mp-Pair))) (setf (sv-key m) "array") (setf (sv-value m) (sv-array self)) m) )))


;; Grammars

(if (not (ignore-errors (find-class 'mp-MiniPerl6-Grammar)))
  (defclass mp-MiniPerl6-Grammar () ()))
(let (x)
  (setq x (make-instance 'mp-MiniPerl6-Grammar))
  (defun proto-mp-MiniPerl6-Grammar () x))

;; token <space>
(if (not (ignore-errors (find-method 'sv-space () ())))
   (defgeneric sv-space (sv-grammar &optional sv-str sv-pos)
      (:documentation "a method")))
(defmethod sv-space ((sv-grammar mp-MiniPerl6-Grammar) &optional sv-str sv-pos)
    (if (ignore-errors (or (char= (aref sv-str sv-pos) #\Space) (char= (aref sv-str sv-pos) #\Tab)))
         (let ((m (make-instance 'mp-MiniPerl6-Match))) 
            (setf (sv-str m) sv-str)(setf (sv-from m) sv-pos)(setf (sv-to m) (+ sv-pos 1))(setf (sv-bool m) 1) m)
         (let ((m (make-instance 'mp-MiniPerl6-Match))) 
            (setf (sv-bool m) nil) m)))

;; token <digit>
(if (not (ignore-errors (find-method 'sv-digit () ())))
  (defgeneric sv-digit (sv-grammar &optional sv-str sv-pos)
      (:documentation "a method")))
(defmethod sv-digit ((sv-grammar mp-MiniPerl6-Grammar) &optional sv-str sv-pos)
    (if (ignore-errors (digit-char-p (aref sv-str sv-pos)))
         (let ((m (make-instance 'mp-MiniPerl6-Match))) 
            (setf (sv-str m) sv-str)(setf (sv-from m) sv-pos)(setf (sv-to m) (+ sv-pos 1))(setf (sv-bool m) 1) m)
         (let ((m (make-instance 'mp-MiniPerl6-Match))) 
            (setf (sv-bool m) nil) m)))

;; token <word>
(if (not (ignore-errors (find-method 'sv-word () ())))
  (defgeneric sv-word (sv-grammar &optional sv-str sv-pos)
      (:documentation "a method")))
(defmethod sv-word ((sv-grammar mp-MiniPerl6-Grammar) &optional sv-str sv-pos)
    (if (ignore-errors (or (alphanumericp (aref sv-str sv-pos)) (char= (aref sv-str sv-pos) #\_)))
         (let ((m (make-instance 'mp-MiniPerl6-Match))) 
            (setf (sv-str m) sv-str)(setf (sv-from m) sv-pos)(setf (sv-to m) (+ sv-pos 1))(setf (sv-bool m) 1) m)
         (let ((m (make-instance 'mp-MiniPerl6-Match))) 
            (setf (sv-bool m) nil) m)))

;; token <is_newline>
(if (not (ignore-errors (find-method 'sv-is_newline () ())))
   (defgeneric sv-is_newline (sv-grammar &optional sv-str sv-pos)
      (:documentation "a method")))
(defmethod sv-is_newline ((sv-grammar mp-MiniPerl6-Grammar) &optional sv-str sv-pos)
    (if (ignore-errors (char= (aref sv-str sv-pos) #\Return))
         (progn (setf sv-pos (+ sv-pos 1))
                (if (ignore-errors (char= (aref sv-str sv-pos) #\Newline)) (setf sv-pos (+ sv-pos 1)))
                (let ((m (make-instance 'mp-MiniPerl6-Match))) 
                    (setf (sv-str m) sv-str)(setf (sv-from m) sv-pos)(setf (sv-to m) sv-pos)(setf (sv-bool m) 1) m))
    (if (ignore-errors (char= (aref sv-str sv-pos) #\Newline))
         (progn (setf sv-pos (+ sv-pos 1))
                (if (ignore-errors (char= (aref sv-str sv-pos) #\Return)) (setf sv-pos (+ sv-pos 1)))
                (let ((m (make-instance 'mp-MiniPerl6-Match))) 
                    (setf (sv-str m) sv-str)(setf (sv-from m) sv-pos)(setf (sv-to m) sv-pos)(setf (sv-bool m) 1) m))
         (let ((m (make-instance 'mp-MiniPerl6-Match))) 
            (setf (sv-bool m) nil) m))))

;; token <not_newline>
(if (not (ignore-errors (find-method 'sv-not_newline () ())))
   (defgeneric sv-not_newline (sv-grammar &optional sv-str sv-pos)
      (:documentation "a method")))
(defmethod sv-not_newline ((sv-grammar mp-MiniPerl6-Grammar) &optional sv-str sv-pos)
    (if (not (ignore-errors (or (char= (aref sv-str sv-pos) #\Return) (char= (aref sv-str sv-pos) #\Newline))))
         (let ((m (make-instance 'mp-MiniPerl6-Match))) 
            (setf (sv-str m) sv-str)(setf (sv-from m) sv-pos)(setf (sv-to m) (+ sv-pos 1))(setf (sv-bool m) 1) m)
         (let ((m (make-instance 'mp-MiniPerl6-Match))) 
            (setf (sv-bool m) nil) m)))


;; Match objects

(if (not (ignore-errors (find-class 'mp-MiniPerl6-Match)))
  (defclass mp-MiniPerl6-Match () 
    (hash array)))

(defvar sv-MATCH (make-instance 'mp-MiniPerl6-Match))

(if (not (ignore-errors (find-method 'sv-hash () ())))
  (defgeneric sv-hash (self)
      (:documentation "get a hash value")))
(defmethod sv-hash ((m mp-MiniPerl6-Match)) 
  (or 
    (ignore-errors (slot-value m 'hash))
    (setf (slot-value m 'hash) (make-hash-table :test 'equal))))

(if (not (ignore-errors (find-method 'sv-array () ())))
  (defgeneric sv-array (self)
      (:documentation "get an array value")))
(defmethod sv-array ((m mp-MiniPerl6-Match)) 
  (or 
    (ignore-errors (slot-value m 'array))
    (setf (slot-value m 'array) (list (sv-undef) (sv-undef) (sv-undef)))))
    ;; (setf (slot-value m 'array) (make-array 10 :adjustable 1))))

;; compiler utils

(if (not (ignore-errors (find-method 'sv-newline () ())))
  (defgeneric sv-newline (class)
      (:documentation "the newline string")))
(defmethod sv-newline (class)
  (format nil "~%"))

;; function replace-substring pasted from: 
;;   http://web.mit.edu/maxima_v5.13.0/src/maxima-5.13.0/configure.lisp
(defun replace-substring (in-string old new) 
  (let ((result ""))
    (do ((begin 0)
     (end (search old in-string) 
          (search old in-string :start2 begin)))
    ((>= begin (length in-string)) 'done)
      (if end
      (progn (setf result (concatenate 'string result 
                       (subseq in-string begin end)
                       new))
         (setf begin (+ end (length old))))
      (progn (setf result (concatenate 'string result 
                       (subseq in-string begin
                           (length in-string))))
         (setf begin (length in-string)))))
    result))

(if (not (ignore-errors (find-method 'sv-lisp_escape_string () ())))
  (defgeneric sv-hash (self)
      (:documentation "escape a lisp string value")))
(defmethod sv-lisp_escape_string ((s string)) 
    (replace-substring
        (replace-substring s "\\" "\\\\")
                             "\"" "\\\""))

(if (not (ignore-errors (find-method 'sv-perl_escape_string () ())))
  (defgeneric sv-hash (self)
      (:documentation "escape a single quoted perl string value")))
(defmethod sv-perl_escape_string ((s string)) 
    (replace-substring
        (replace-substring s "\\" "\\\\")
                             "'" "\\\'"))

(if (not (ignore-errors (find-method 'sv-to_lisp_namespace () ())))
  (defgeneric sv-hash (self)
      (:documentation "escape a lisp namespace string")))
(defmethod sv-to_lisp_namespace ((s string)) 
    (format nil "mp-~a" (replace-substring s "::" "-")))

;; function join pasted from:
;;   http://coding.derkeiler.com/Archive/Lisp/comp.lang.lisp/2007-11/msg00971.html
(defun sv-join (list &optional (delim ""))
  (with-output-to-string (s)
    (when list
        (format s "~A" (first list))
        (dolist (element (rest list))
          (format s "~A~A" delim element)))))

