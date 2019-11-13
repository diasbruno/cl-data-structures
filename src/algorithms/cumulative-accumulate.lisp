(in-package #:cl-data-structures.algorithms)


(defclass cumulative-state ()
  ((%state :initarg :state
           :accessor access-state)
   (%result :initarg :result
            :reader read-result)
   (%function :initarg :function
              :reader read-function)
   (%cumulative-key :initarg :cumulative-key
                    :reader read-cumulative-key)))


(defmethod cl-ds.utils:cloning-information append
    ((object cumulative-state))
  '((:state access-state)
    (:result read-result)
    (:function read-function)
    (:cumulative-key read-cumulative-key)))


(defclass cumulative-accumulate-range (cl-ds.alg:proxy-range
                                       cl-ds:fundamental-forward-range
                                       cumulative-state)
  ((%initial-state :initarg :state
                   :reader read-initial-state)))


(defmethod cl-ds:clone ((range cumulative-accumulate-range))
  (apply #'make (type-of range)
         :original-range (read-original-range range)
         :result (read-result range)
         :function (read-function range)
         :cumulative-key (read-cumulative-key range)
         (if (slot-boundp range '%state)
             (list :state (access-state range))
             nil)))


(defmethod cl-ds:reset! ((range cumulative-accumulate-range))
  (call-next-method)
  (if (slot-boundp range '%initial-state)
      (setf (access-state range) (read-initial-state range))
      (slot-makunbound range '%state))
  range)


(defmethod cl-ds:peek-front ((range cumulative-accumulate-range))
  (bind (((:values v more) (call-next-method)))
    (if (no more)
        (values v nil)
        (let* ((key (read-cumulative-key range))
               (function (read-function range))
               (result (read-result range)))
          (values
           (if (slot-boundp range '%state)
               (~>> (funcall key v)
                    (funcall function (access-state range))
                    (funcall result))
               v)
           t)))))


(defun consume-impl (range v)
  (let* ((key (read-cumulative-key range))
         (function (read-function range))
         (result (read-result range)))
    (values
     (if (slot-boundp range '%state)
         (let* ((state (access-state range))
                (next-state
                  (~>> (funcall key v)
                       (funcall function state))))
           (setf (access-state range) next-state)
           (funcall result next-state))
         (let ((r (funcall key v)))
           (setf (slot-value range '%state) r)
           r))
     t)))


(defmethod cl-ds:consume-front ((range cumulative-accumulate-range))
  (bind (((:values v more) (call-next-method)))
    (if (no more)
        (values v nil)
        (consume-impl range v))))


(defmethod cl-ds:traverse ((range cumulative-accumulate-range) function)
  (call-next-method range
                    (lambda (elt)
                      (funcall function
                               (consume-impl range elt)))))


(defmethod cl-ds:across ((range cumulative-accumulate-range) function)
  (let* ((state (apply #'make 'cumulative-state
                       :result (read-result range)
                       :function (read-function range)
                       :cumulative-key (read-cumulative-key range)
                       (if (slot-boundp range '%state)
                           (list :state (access-state range))
                           nil))))
    (call-next-method range
                      (lambda (elt)
                        (funcall function
                                 (consume-impl state elt))))))


(defclass cumulative-accumulate-function (cl-ds.alg.meta:layer-function)
  ()
  (:metaclass closer-mop:funcallable-standard-class))


(defgeneric cumulative-accumulate (range function
                                   &key key result initial-value)
  (:generic-function-class cumulative-accumulate-function)
  (:method (range function
            &key
              (key #'identity) (result #'identity)
              (initial-value nil initial-value-bound))
    (ensure-functionf key result function)
    (cl-ds.alg.meta:apply-range-function
     range
     #'cumulative-accumulate
     :function function
     :result result
     :initial-value initial-value
     :initial-value-bound initial-value-bound
     :cumulative-key key)))


(defmethod cl-ds.alg.meta:apply-layer ((range cl-ds:fundamental-forward-range)
                                       (fn cumulative-accumulate-function)
                                       &rest all
                                       &key
                                         key function result
                                         initial-value
                                         initial-value-bound)
  (declare (ignore all))
  (apply #'cl-ds.alg:make-proxy
         range 'cumulative-accumulate-range
         :cumulative-key key
         :function function
         :result result
         (if initial-value-bound
             (list :state initial-value)
             nil)))


(defclass cumulative-accumulate-aggregator (cl-ds.alg.meta:abstract-proxy-aggregator
                                            cumulative-state)
  ())


(defmethod cl-ds.alg.meta:pass-to-aggregation ((aggregator cumulative-accumulate-aggregator)
                                               element)
  (let ((inner-aggregator (cl-ds.alg.meta:read-inner-aggregator aggregator)))
    (~>> element
         (consume-impl aggregator)
         (cl-ds.alg.meta:pass-to-aggregation inner-aggregator))))


(defmethod proxy-range-aggregator-outer-fn ((range cumulative-accumulate-function)
                                            key
                                            function
                                            outer-fn
                                            arguments)
  (lambda ()
    (apply #'make 'cumulative-accumulate-aggregator
           :result (read-result range)
           :function (read-function range)
           :cumulative-key (read-cumulative-key range)
           :key key
           (if (slot-boundp range '%state)
               (list :state (access-state range))
               nil))))


(defmethod cl-ds.alg.meta:across-aggregate ((range cumulative-accumulate-function) function)
  (~> range
      read-original-range
      (cl-ds.alg.meta:across-aggregate function)))
