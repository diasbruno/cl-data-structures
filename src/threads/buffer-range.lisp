(in-package #:cl-data-structures.threads)


(defclass buffer-range (cl-ds.alg:transparent-to-chunking-mixin
                        cl-ds.alg:proxy-range)
  ((%limit :initarg :limit
           :reader read-limit)
   (%context-function :initarg :context-function
                      :reader read-context-function)))


(defclass forward-buffer-range (buffer-range cl-ds.alg:forward-proxy-range)
  ())


(defclass chunked-buffer-range (forward-buffer-range)
  ((%chunk-size :initarg :chunk-size
                :reader read-chunk-size)))


(defclass bidirectional-buffer-range (buffer-range cl-ds.alg:bidirectional-proxy-range)
  ())


(defclass random-access-buffer-range (buffer-range cl-ds.alg:random-access-proxy-range)
  ())


(defmethod cl-ds:clone ((range buffer-range))
  (make (type-of range)
        :limit (read-limit range)
        :context-function (read-context-function range)
        :original-range (cl-ds.alg:read-original-range range)))


(defmethod cl-ds:clone ((range chunked-buffer-range))
  (make 'chunked-buffer-range
        :original-range (~> range cl-ds.alg:read-original-range cl-ds:clone)
        :limit (read-limit range)
        :context-function (read-context-function range)
        :chunk-size (read-chunk-size range)))


(defun traverse/accross-thread-buffer-range (traverse/accross range function)
  (bind ((queue (lparallel.queue:make-queue :fixed-capacity (read-limit range)))
         ((:flet enque (data))
          (lparallel.queue:push-queue data queue))
         (og-range (cl-ds.alg::read-original-range range))
         (context-function (read-context-function range))
         (fn (lambda ()
               (block nil
                 (handler-case
                     (funcall (funcall
                               context-function
                               (lambda ()
                                 (funcall traverse/accross
                                          (compose #'enque (rcurry #'list* t))
                                          og-range))))
                   (condition (e)
                     (enque (list* e :error))
                     (return nil))))
               (enque '(nil))))
         (thread (bt:make-thread fn :name "buffer-range thread"))
         (all-good nil))
    (unwind-protect
        (iterate
          (for (data . more) = (lparallel.queue:pop-queue queue))
          (while more)
          (when (eql more :error)
            (error data))
          (funcall function data)
          (finally (bt:join-thread thread)
                   (setf all-good t)))
      (unless all-good
        (bt:destroy-thread thread)))
    range))


(defmethod cl-ds:traverse (function (range buffer-range))
  (traverse/accross-thread-buffer-range #'cl-ds:traverse range function))


(defmethod cl-ds:across (function (range buffer-range))
  (traverse/accross-thread-buffer-range #'cl-ds:across range function))


(defmethod cl-ds:chunked ((range buffer-range) &optional chunk-size-hint)
  (if-let ((chunked (~> range cl-ds.alg:read-original-range
                        (cl-ds:chunked chunk-size-hint))))
    chunked
    (make 'chunked-buffer-range
          :original-range (cl-ds.alg:read-original-range range)
          :limit (read-limit range)
          :context-function (read-context-function range)
          :chunk-size (or chunk-size-hint (read-limit range)))))


(defmethod cl-ds:consume-front ((range chunked-buffer-range))
  (let ((og-range (cl-ds.alg:read-original-range range)))
    (multiple-value-bind (item more) (cl-ds:consume-front og-range)
      (if more
          (let* ((chunk-size (read-chunk-size range))
                 (result (make-array chunk-size
                                     :adjustable t
                                     :fill-pointer 1)))
            (setf (aref result 0) item)
            (iterate
              (for i from 1 below chunk-size)
              (for (values elt m) = (cl-ds:consume-front og-range))
              (vector-push-extend elt result))
            (values (cl-ds:whole-range result)
                    t))
          (values nil nil)))))


(defmethod cl-ds:peek-front ((range chunked-buffer-range))
  (let ((og-range (~> range cl-ds.alg:read-original-range cl-ds:clone)))
    (multiple-value-bind (item more) (cl-ds:consume-front og-range)
      (if more
          (let* ((chunk-size (read-chunk-size range))
                 (result (make-array chunk-size
                                     :adjustable t
                                     :fill-pointer 1)))
            (setf (aref result 0) item)
            (iterate
              (for i from 1 below chunk-size)
              (for (values elt m) = (cl-ds:consume-front og-range))
              (vector-push-extend elt result))
            (values (cl-ds:whole-range result)
                    t))
          (values nil nil)))))


(defclass thread-buffer-function (cl-ds.alg.meta:layer-function)
  ()
  (:metaclass closer-mop:funcallable-standard-class))


(defgeneric thread-buffer (range limit &key context-function)
  (:generic-function-class thread-buffer-function)
  (:method (range limit &key (context-function #'identity))
    (cl-ds.alg.meta:apply-range-function range #'thread-buffer
                                         :limit limit
                                         :context-function context-function)))


(defmethod cl-ds.alg.meta:apply-layer ((range cl-ds:fundamental-forward-range)
                                       (fn thread-buffer-function)
                                       &rest all &key limit context-function)
  (declare (ignore all))
  (cl-ds.alg:make-proxy range 'forward-buffer-range
                        :limit limit
                        :context-function context-function))


(defmethod cl-ds.alg.meta:apply-layer ((range cl-ds:fundamental-random-access-range)
                                       (fn thread-buffer-function)
                                       &rest all &key limit context-function)
  (declare (ignore all))
  (cl-ds.alg:make-proxy range 'random-access-buffer-range
                        :limit limit
                        :context-function context-function))


(defmethod cl-ds.alg.meta:apply-layer ((range cl-ds:fundamental-bidirectional-range)
                                       (fn thread-buffer-function)
                                       &rest all &key limit context-function)
  (declare (ignore all))
  (cl-ds.alg:make-proxy range 'bidirectional-buffer-range
                        :limit limit
                        :context-function context-function))
