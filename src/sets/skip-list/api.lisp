(cl:in-package #:cl-ds.sets.skip-list)


(defclass mutable-skip-list-set (cl-ds.sets:fundamental-set
                                 cl-ds.common.skip-list:fundamental-skip-list)
  ((%test-function :initarg :test-function
                   :accessor access-test-function)))


(defmethod cl-ds:clone ((object mutable-skip-list-set))
  (lret ((result (call-next-method)))
    (setf (access-test-function result) (access-test-function object))))


(defmethod cl-ds:empty-clone ((object mutable-skip-list-set))
  (lret ((result (call-next-method)))
    (setf (access-test-function result) (access-test-function object))))


(defclass mutable-skip-list-set-range (cl-ds.common.skip-list:fundamental-skip-list-range)
  ())


(defmethod cl-ds:whole-range ((object mutable-skip-list-set))
  (make-instance 'mutable-skip-list-set-range
                 :current-node (~> object
                                   cl-ds.common.skip-list:read-pointers
                                   (aref 0))))


(defmethod cl-ds:consume-front ((range mutable-skip-list-set-range))
  (let ((result (call-next-method)))
    (if (null result)
        (values nil nil)
        (values (cl-ds.common.skip-list:skip-list-node-content result)
                t))))


(defmethod cl-ds:peek-front ((range mutable-skip-list-set-range))
  (let ((result (call-next-method)))
    (if (null result)
        (values nil nil)
        (values (cl-ds.common.skip-list:skip-list-node-content result)
                t))))


(defmethod cl-ds:traverse ((range mutable-skip-list-set-range)
                           function)
  (ensure-functionf function)
  (call-next-method range
                    (lambda (node)
                      (declare (type cl-ds.common.skip-list:skip-list-node
                                     node)
                               (optimize (speed 3)))
                      (~>> node
                           cl-ds.common.skip-list:skip-list-node-content
                           (funcall function))))
  range)


(defmethod cl-ds:across ((range mutable-skip-list-set-range)
                         function)
  (ensure-functionf function)
  (call-next-method range
                    (lambda (node)
                      (declare (type cl-ds.common.skip-list:skip-list-node
                                     node)
                               (optimize (speed 3)))
                      (~>> node
                           cl-ds.common.skip-list:skip-list-node-content
                           (funcall function))))
  range)


(defmethod cl-ds.meta:position-modification
    ((function cl-ds.meta:put!-function)
     (structure mutable-skip-list-set)
     container
     location
     &rest all)
  (declare (ignore all container))
  (bind ((pointers (cl-ds.common.skip-list:read-pointers structure))
         (test (cl-ds.common.skip-list:read-ordering-function structure))
         ((:values current prev)
          (cl-ds.common.skip-list:locate-node pointers location test))
         (result (aref current 0)))
    (bind ((content (cl-ds.common.skip-list:skip-list-node-content result)))
      (if (~> structure access-test-function (funcall content))
          (values structure
                  (cl-ds.common:make-eager-modification-operation-status
                   t content nil))
          (let ((new-node (cl-ds.common.skip-list:make-skip-list-node-of-random-level
                           (array-dimension pointers 0))))
            (cl-ds.common.skip-list:insert-node-between! current prev
                                                         new-node)
            (setf (cl-ds.common.skip-list:skip-list-node-content new-node)
                  location)
            (cl-ds.common.skip-list:update-head-pointers! structure new-node)
            (incf (cl-ds.common.skip-list:access-size structure))
            (values structure
                    (cl-ds.common:make-eager-modification-operation-status
                     nil nil t)))))))


(defmethod cl-ds.meta:position-modification
    ((function cl-ds.meta:erase!-function)
     (structure mutable-skip-list-set)
     container
     location
     &rest all)
  (declare (ignore all container))
  (bind ((pointers (cl-ds.common.skip-list:read-pointers structure))
         (test (cl-ds.common.skip-list:read-ordering-function structure))
         ((:values current prev)
          (cl-ds.common.skip-list:locate-node pointers location test))
         (result (aref current 0)))
    (when (null result)
      (return-from cl-ds.meta:position-modification
        (values structure
                cl-ds.common:empty-eager-modification-operation-status)))
    (let ((content (cl-ds.common.skip-list:skip-list-node-content result)))
      (if (~> structure access-test-function (funcall content))
          (let ((rests (cl-ds.common.skip-list:skip-list-node-pointers
                        result))
                (level (cl-ds.common.skip-list:skip-list-node-level
                        result)))
            (iterate
              (declare (type fixnum i))
              (for i from (1- level) downto 0)
              (if (eq (aref pointers i) result)
                  (setf (aref pointers i)
                        (if (< i level)
                            (aref rests i)
                            nil))
                  (finish)))
            (when-let ((previous (aref prev 0)))
              (iterate
                (declare (type fixnum i))
                (for i from 0
                     below (cl-ds.common.skip-list:skip-list-node-level previous))
                (setf (cl-ds.common.skip-list:skip-list-node-at previous i)
                      (aref rests i))))
            (decf (cl-ds.common.skip-list:access-size structure))
            (values
             structure
             (cl-ds.common:make-eager-modification-operation-status
              t content t)))
          (values structure
                  cl-ds.common:empty-eager-modification-operation-status)))))


(defmethod cl-ds:at ((container mutable-skip-list-set)
                     location
                     &rest more-locations)
  (cl-ds:assert-one-dimension more-locations)
  (let ((result (~> container
                    (cl-ds.common.skip-list:skip-list-locate-node location)
                    (aref 0))))
    (when (null result)
      (return-from cl-ds:at (values nil nil)))
    (let ((content (cl-ds.common.skip-list:skip-list-node-content result)))
      (if (~> container read-test-function (funcall content))
          (values t t)
          (values nil nil)))))


(defun make-mutable-skip-list-set (ordering test
                                   &key (maximum-level 32))
  (check-type maximum-level positive-fixnum)
  (make-instance 'mutable-skip-list-set
                 :ordering-function ordering
                 :maximum-level maximum-level
                 :test-function test
                 :pointers (make-array maximum-level
                                       :initial-element nil)))


(defmethod cl-ds:make-from-traversable (traversable
                                        (class (eql 'mutable-skip-list-set))
                                        &rest arguments)
  (lret ((result (apply #'make-mutable-skip-list-set arguments)))
    (cl-ds:traverse traversable
                    (lambda (x) (cl-ds:put! result x)))))
