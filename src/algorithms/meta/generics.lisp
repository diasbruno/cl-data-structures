(cl:in-package #:cl-data-structures.algorithms.meta)

#|
Top level aggregator protocol.
|#


(defstruct aggregator
  (pass #'identity :type (-> (t) t))
  (extract (lambda () nil) :type (-> () t)))

(declaim (inline pass-to-aggregation))
(-> pass-to-aggregation (aggregator t) null)
(defun pass-to-aggregation (aggregator element)
  (declare (type aggregator aggregator)
           (optimize (speed 3) (safety 0)))
  (~> aggregator aggregator-pass (funcall element))
  nil)

(declaim (inline extract-result))
(-> extract-result (aggregator) t)
(defun extract-result (aggregator)
  (declare (type aggregator aggregator)
           (optimize (speed 3) (safety 0)))
  (~> aggregator aggregator-extract funcall))

#|
Range function invokaction protocol.
|#

(defgeneric apply-layer (range function arguments))

(defgeneric apply-range-function (range function arguments))

(defgeneric apply-aggregation-function (range function arguments))

(defgeneric make-state (aggregation-function
                        &rest all
                        &key &allow-other-keys))

(defgeneric state-result (function state)
  (:method ((function aggregation-function) state)
    state))

(defgeneric across-aggregate (range function)
  (:method ((range cl-ds:traversable) function)
    (cl-ds:across range function))
  (:method ((range sequence) function)
    (map nil function range)
    range))

(defgeneric aggregator-constructor (range outer-constructor
                                    function arguments)
  (:method ((range cl:sequence) (outer-constructor function)
            (function aggregation-function) (arguments list))
    outer-constructor)
  (:method ((range cl-ds:traversable) (outer-constructor function)
            (function aggregation-function) (arguments list))
    outer-constructor))

(defun construct-aggregator (range function arguments)
  (funcall (aggregator-constructor range nil function arguments)))
