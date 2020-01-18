(in-package #:cl-data-structures.algorithms)


(defclass group-by-proxy (proxy-range)
  ((%groups :initarg :groups
            :type hash-table
            :reader read-groups)
   (%key :initarg :key
         :reader read-key)))


(defclass group-by-result-range (hash-table-range)
  ())


(defmethod cl-ds.utils:cloning-information append
    ((range group-by-proxy))
  '((:groups read-groups)
    (:key read-key)))


(defclass forward-group-by-proxy (group-by-proxy
                                  fundamental-forward-range)
  ())


(defclass bidirectional-group-by-proxy (forward-group-by-proxy
                                        bidirectional-proxy-range)
  ())


(defclass random-access-group-by-proxy (bidirectional-group-by-proxy
                                        random-access-proxy-range)
  ())


(defmethod initialize-instance :before ((instance group-by-proxy)
                                        &key test groups key &allow-other-keys)
  (declare (optimize (debug 3)))
  (setf (slot-value instance '%groups) (if (null test)
                                           (copy-hash-table groups)
                                           (make-hash-table :test test))
        (slot-value instance '%key) key))


(defclass group-by-function (layer-function)
  ()
  (:metaclass closer-mop:funcallable-standard-class))


(defclass group-by-aggregator (cl-ds.alg.meta:fundamental-aggregator)
  ((%groups :initarg :groups
            :type hash-table
            :reader read-groups)
   (%outer-fn :initarg :outer-fn
              :reader read-outer-fn)
   (%group-by-key :initarg :group-by-key
                  :reader read-key)))


(defclass linear-group-by-aggregator (group-by-aggregator)
  ())


(defmethod cl-ds.alg.meta:pass-to-aggregation ((aggregator group-by-aggregator)
                                               element)
  (bind (((:slots %group-by-key %groups %outer-fn) aggregator)
         (selected (~>> element (funcall %group-by-key)))
         (group (gethash selected %groups)))
    (when (null group)
      (setf group (funcall %outer-fn)
            (gethash selected %groups) group))
    (cl-ds.alg.meta:pass-to-aggregation group element)))


(defmethod cl-ds.alg.meta:extract-result ((aggregator group-by-aggregator))
  (bind (((:slots %key %groups %outer-fn) aggregator)
         (groups (copy-hash-table %groups)))
    (maphash (lambda (key aggregator)
               (setf (gethash key groups)
                     (cl-ds.alg.meta:extract-result aggregator)))
             %groups)
    (make-instance 'group-by-result-range
                   :hash-table groups
                   :keys (~> groups hash-table-keys (coerce 'vector))
                   :begin 0
                   :end (hash-table-count groups))))


(defgeneric group-by (range &key test key)
  (:generic-function-class group-by-function)
  (:method (range &key (test 'eql) (key #'identity))
    (apply-range-function range #'group-by
                          :test test
                          :key key)))


(defmethod proxy-range-aggregator-outer-fn ((range group-by-proxy)
                                            key
                                            function
                                            outer-fn
                                            arguments)
  (bind (((:slots %groups) range)
         (groups (copy-hash-table %groups))
         (outer-fn (call-next-method)))
    (lambda ()
      (make 'linear-group-by-aggregator
            :groups (copy-hash-table groups)
            :outer-fn outer-fn
            :key key
            :group-by-key (read-key range)))))


(defmethod apply-layer ((range cl-ds:traversable)
                        (fn group-by-function)
                        &rest all &key test key)
  (declare (ignore all))
  (make-proxy range 'forward-group-by-proxy
              :test test
              :key key))


(defmethod apply-layer ((range fundamental-forward-range)
                        (fn group-by-function)
                        &rest all &key test key)
  (declare (ignore all))
  (make-proxy range 'forward-group-by-proxy
              :test test
              :key key))


(defmethod apply-layer ((range fundamental-bidirectional-range)
                        (fn group-by-function)
                        &rest all &key test key)
  (declare (ignore all))
  (make-proxy range 'bidirectional-group-by-proxy
              :test test
              :key key))


(defmethod apply-layer ((range fundamental-random-access-range)
                        (fn group-by-function)
                        &rest all &key test key)
  (declare (ignore all))
  (make-proxy range 'random-access-group-by-proxy
              :test test
              :key key))
