(cl:in-package #:cl-data-structures.algorithms.meta)

#|
Top level aggregator protocol.
|#

(defmethod extract-result ((aggregator linear-aggregator))
  (bind (((:slots %state %function) aggregator))
    (state-result %function %state)))


(defmethod pass-to-aggregation ((aggregator linear-aggregator)
                                element)
  (bind (((:slots %function %state %key) aggregator))
    (aggregate %function %state (funcall %key element))))


(defmethod construct-aggregator ((range cl-ds:fundamental-container)
                                 key function outer-fn arguments)
  (construct-aggregator (cl-ds:whole-range range)
                        key function
                        outer-fn arguments))


(defmethod construct-aggregator ((range fundamental-forward-range)
                                 key
                                 (function aggregation-function)
                                 (outer-fn (eql nil))
                                 (arguments list))
  (make-linear-aggregator function arguments key))


(defmethod construct-aggregator ((range cl:sequence)
                                 key
                                 (function aggregation-function)
                                 (outer-fn (eql nil))
                                 (arguments list))
  (make-linear-aggregator function arguments key))


(defmethod construct-aggregator ((range cl-ds:traversable)
                                 key
                                 (function aggregation-function)
                                 outer-fn
                                 (arguments list))
  (make-linear-aggregator function arguments key))


(defmethod construct-aggregator ((range cl:sequence)
                                 key
                                 (function aggregation-function)
                                 outer-fn
                                 (arguments list))
  (lret ((result (funcall outer-fn)))
    (setf (slot-value result '%key) key)))


(defmethod expects-content-p ((aggregator linear-aggregator))
  t)


#|
Range function invokaction protocol.
|#

(defmethod apply-range-function ((object cl-ds:fundamental-container)
                                 (function aggregation-function)
                                 &rest all)
  (apply #'apply-aggregation-function
         object
         function
         all))


(defmethod apply-range-function (range
                                 (function aggregation-function)
                                 &rest all)
  (apply #'apply-aggregation-function range function all))


(defmethod apply-range-function ((range cl-ds:traversable)
                                 (function layer-function)
                                 &rest all)
  (warn "Appling range function to ~a object which is not a range."
        range)
  (apply #'apply-layer (cl-ds:clone range) function all))


(defmethod apply-range-function ((range cl-ds:fundamental-range)
                                 (function layer-function)
                                 &rest all &key &allow-other-keys)
  (apply #'apply-layer (cl-ds:clone range) function all))


(defmethod apply-range-function ((range cl:hash-table)
                                 (function layer-function)
                                 &rest all &key &allow-other-keys)
  (apply #'apply-layer (cl-ds:whole-range range) function all))


(defmethod apply-range-function ((range cl:sequence)
                                 (function layer-function)
                                 &rest all &key &allow-other-keys)
  (apply #'apply-layer (cl-ds:whole-range range) function all))


(defmethod apply-range-function ((range cl-ds:fundamental-container)
                                 (function layer-function)
                                 &rest all &key &allow-other-keys)
  (apply #'apply-layer (cl-ds:whole-range range) function all))


(defmethod apply-aggregation-function (range
                                       (function aggregation-function)
                                       &rest all &key (key #'identity)
                                       &allow-other-keys)
  (let ((aggregator (construct-aggregator range key function nil all)))
    (apply #'apply-aggregation-function-with-aggregator
           aggregator range function all)))


(defmethod apply-aggregation-function-with-aggregator
    ((aggregator fundamental-aggregator)
     range
     (function aggregation-function)
     &rest all &key &allow-other-keys)
  (declare (ignore all))
  (across-aggregate range
                    (lambda (x)
                      (pass-to-aggregation aggregator
                                           x)))
  (extract-result aggregator))
