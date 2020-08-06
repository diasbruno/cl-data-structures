(cl:in-package #:cl-data-structures.streaming-algorithms)


(defclass fundamental-minhash ()
  ((%k :initarg :k
       :reader read-k)))


(defclass minhash-corpus (fundamental-minhash)
  ((%table :initarg :table
           :reader read-table)))


(defclass callback-minhash (fundamental-minhash)
  ((%hash-function :initarg :hash-function
                   :reader read-hash-function)))


(defclass polynomial-callback-minhash (callback-minhash)
  ((%hash-array :initarg :hash-array
                :reader read-hash-array)))


(defclass seeds-callback-minhash (callback-minhash)
  ((%seeds :initarg :seeds
           :reader read-seeds)))


(defclass xors-callback-minhash (callback-minhash)
  ((%xors :initarg :xors
          :reader read-xors)))


(defgeneric minhash-corpus-hash-value (corpus element))


(defmethod minhash-corpus-hash-value ((corpus minhash-corpus) element)
  (gethash element (read-table corpus)))


(defmethod minhash-corpus-hash-value ((corpus polynomial-callback-minhash) element)
  (declare (optimize (speed 3) (safety 0)))
  (let* ((k (read-k corpus))
         (hash-array (read-hash-array corpus))
         (result (make-array k :element-type '(unsigned-byte 64)))
         (hash (funcall (ensure-function (read-hash-function corpus)) element)))
    (declare (type fixnum k))
    (iterate
      (declare (type fixnum i))
      (for i from 0 below k)
      (setf (aref result i) (ph:hashval-no-depth hash-array i hash))
      (finally (return result)))))


(defmethod minhash-corpus-hash-value ((corpus seeds-callback-minhash) element)
  (declare (optimize (speed 3) (safety 1)))
  (let* ((k (read-k corpus))
         (seeds (read-seeds corpus))
         (result (make-array k :element-type '(unsigned-byte 64)))
         (function (ensure-function (read-hash-function corpus))))
    (declare (type fixnum k)
             (type (simple-array (unsigned-byte 64) (*)) seeds))
    (iterate
      (declare (type fixnum i))
      (for i from 0 below k)
      (for seed = (aref seeds i))
      (for hash = (funcall function element seed))
      (setf (aref result i) hash)
      (finally (return result)))))


(defmethod minhash-corpus-hash-value ((corpus xors-callback-minhash) element)
  (declare (optimize (speed 3) (safety 1)))
  (let* ((k (read-k corpus))
         (xors (read-xors corpus))
         (result (make-array k :element-type '(unsigned-byte 64)))
         (function (ensure-function (read-hash-function corpus)))
         (hash (funcall function element)))
    (declare (type fixnum k)
             (type (unsigned-byte 64) hash)
             (type (simple-array (unsigned-byte 64) (*)) xors))
    (iterate
      (declare (optimize (speed 3) (safety 0)))
      (declare (type fixnum i))
      (for i from 0 below k)
      (for xor = (aref xors i))
      (setf (aref result i) (logxor xor hash))
      (finally (return result)))))


(defmethod cl-ds:clone ((object minhash-corpus))
  (make (class-of object)
        :table (~> object read-table copy-hash-table)
        :k (read-k object)))


(defmethod cl-ds:clone ((object callback-minhash))
  (make (class-of object)
        :hash-function (read-hash-function object)
        :hash-array (read-hash-array object)))


(cl-ds.utils:define-list-of-slots minhash-corpus ()
  (table read-table)
  (k read-k))


(cl-ds.alg.meta:define-aggregation-function gather-minhash-corpus
    gather-corpus-function
    (:range k &key key corpus)
    (:range k &key (key #'identity)
     (corpus (make-instance 'minhash-corpus
                            :k k
                            :table (make-hash-table :test 'equal))))
    (%table %k %corpus)
    ((check-type k positive-fixnum)
     (setf %corpus (cl-ds:clone corpus)
           %table (read-table %corpus)
           %k (read-k %corpus)))
    ((element)
     (ensure (gethash element %table) (make-array %k :element-type '(unsigned-byte 64))))
    ((iterate
       (with corpus-size = (hash-table-count %table))
       (with input-list = (~>> %table hash-table-alist))
       (with pointers = (make-hash-table :test 'eq))
       (repeat %k)
       (iterate
         (for i from 0 below corpus-size)
         (for (key . value) in (shuffle input-list))
         (for pointer = (gethash value pointers 0))
         (setf (aref value pointer) i)
         (incf (gethash value pointers 0)))
       (finally (return %corpus)))))


(defun make-minhash (k &key
                         (mode :polynomial)
                         (hash-function #'sxhash)
                         hash-array
                         xors
                         seeds)
  (check-type mode (member :polynomial :seeds :logxor))
  (switch (mode)
    (:polynomial
     (make 'polynomial-callback-minhash
           :k k
           :hash-function hash-function
           :hash-array (or hash-array
                           (ph:make-hash-array k))))
    (:logxor
     (make 'xors-callback-minhash
           :k k
           :hash-function hash-function
           :xors (or xors
                     (map-into (make-array k :element-type '(unsigned-byte 64))
                               (curry #'random (1+ ph:+max-64-bits+))))))
    (:seeds
     (make 'seeds-callback-minhash
           :k k
           :hash-function hash-function
           :seeds (or seeds
                      (map-into (make-array k :element-type '(unsigned-byte 64))
                                (curry #'random (1+ ph:+max-64-bits+))))))))


(-> minhash-corpus-minhash (minhash-corpus list) (simple-array (unsigned-byte 64) (*)))
(defun minhash-corpus-minhash (corpus elements)
  (declare (optimize (speed 3) (safety 0) (debug 0)))
  (cl-ds.utils:with-slots-for (corpus minhash-corpus)
    (bind ((count (the fixnum (read-k corpus)))
           (hash-table table)
           (minis (make-array count :element-type '(unsigned-byte 64)
                                    :initial-element most-positive-fixnum))
         ((:flet impl (element))
          (let ((sub (the (simple-array (unsigned-byte 64) (*))
                          (gethash element hash-table))))
            (unless (null sub)
              (iterate
                (declare (type fixnum i))
                (for i from 0 below count)
                (minf (aref minis i) (aref sub i)))))))
    (cl-ds:across elements #'impl)
    minis)))


(defgeneric minhash (corpus elements))


(defmethod minhash ((corpus minhash-corpus) elements)
  (minhash-corpus-minhash corpus elements))


(defmethod minhash ((corpus fundamental-minhash) elements)
  (declare (optimize (speed 3) (debug 0) (safety 1)))
  (bind ((count (the fixnum (read-k corpus)))
         (minis (make-array count :element-type '(unsigned-byte 64)
                                  :initial-element most-positive-fixnum))
         ((:flet impl (element))
          (let ((sub (minhash-corpus-hash-value corpus element)))
            (declare (type (or null (simple-array (unsigned-byte 64) (*))) sub))
            (unless (null sub)
              (iterate
                (declare (type fixnum i))
                (for i from 0 below count)
                (minf (aref minis i) (aref sub i)))))))
    (cl-ds:across elements #'impl)
    minis))


(-> minhash-jaccard/fixnum ((simple-array (unsigned-byte 64) (*))
                            (simple-array (unsigned-byte 64) (*)))
    fixnum)
(defun minhash-jaccard/fixnum (a b)
  (declare (optimize (speed 3) (safety 0) (debug 0)))
  (cl-ds.utils:lolol (a b)
    (check-type a (simple-array (unsigned-byte 64) (*)))
    (check-type b (simple-array (unsigned-byte 64) (*)))
    (unless (= (length a) (length b))
      (error 'cl-ds:incompatible-arguments
             :parameters '(a b)
             :values (list a b)
             :format-control "Lengths of input vectors must be equal."))
    (iterate
      (declare (type fixnum i len result))
      (with len = (length a))
      (with result = len)
      (for i from 0 below len)
      (when (= (aref a i) (aref b i))
        (decf result))
      (finally (return result)))))


(-> minhash-jaccard/single-float ((simple-array (unsigned-byte 64) (*))
                                  (simple-array (unsigned-byte 64) (*)))
    single-float)
(defun minhash-jaccard/single-float (a b)
  (declare (optimize (speed 3)))
  (let ((result (minhash-jaccard/fixnum a b))
        (length (length a)))
    (declare (type fixnum result length))
    (/ (coerce result 'single-float) length)))


(-> minhash-jaccard/double-float ((simple-array (unsigned-byte 64) (*))
                                  (simple-array (unsigned-byte 64) (*)))
    double-float)
(defun minhash-jaccard/double-float (a b)
  (declare (optimize (speed 3)))
  (let ((result (minhash-jaccard/fixnum a b))
        (length (length a)))
    (declare (type fixnum result length))
    (/ (coerce result 'double-float) length)))
