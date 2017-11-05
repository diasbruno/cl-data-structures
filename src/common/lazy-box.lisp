(in-package #:cl-data-structures.common)


(defstruct changes
  (content (vect) :type vector)
  (parent nil :type (or changes null))
  (end-index 1 :type fixnum)
  (unique t :type boolean))


(defun execute-changes (changes instance)
  (declare (type (or null changes) changes))
  (unless (null changes)
    (let ((parent (changes-parent changes)))
      (unless (null parent)
        (execute-changes parent instance)))
    (cl-ds.utils:with-vectors ((content (changes-content changes)))
      (iterate
        (for i from 0 below (changes-end-index changes))
        (funcall (content i) instance)))))


(defun add-change (changes next)
  (if (null changes)
      (make-changes :content (vect next))
      (if (changes-unique changes)
          (progn
            (vector-push-extend next (changes-content changes))
            (setf (changes-unique changes) nil)
            (make-changes :content (changes-content changes)
                          :end-index (1+ (changes-end-index changes))))
          (make-changes :content (vect next)
                        :parent changes))))


(defclass lazy-modification-operation-status
    (cl-ds:fundamental-modification-operation-status)
  ((%eager-status :accessor access-eager-status
                  :type eager-modification-operation-status
                  :initarg :eager-status)
   (%lazy-instance :reader read-lazy-instance
                   :writer write-lazy-instance
                   :initarg :lazy-instance)))


(defclass box-container (cl-ds:fundamental-container)
  ((%content :initarg :content
             :type fundamental-container
             :accessor access-content)))


(defclass lazy-box-container (cl-ds:lazy box-container)
  ((%operations :initform nil
                :type (or null changes)
                :initarg :operations
                :accessor access-operations)))


(-> force-version (lazy-box-container) lazy-box-container)
(defun force-version (instance)
  (with-accessors ((operations access-operations)
                   (content access-content))
      instance
    (let ((transactional-instance (cl-ds:become-transactional
                                   content)))
      (execute-changes operations transactional-instance)
      (setf operations nil)
      (setf content transactional-instance)))
  instance)


(defmethod cl-ds:position-modification (operation (container lazy-box-container) location &rest args &key &allow-other-keys)
  (nest
   (with-accessors ((operations access-operations)
                    (content access-content))
       container)
   (let ((lazy-status (make 'lazy-modification-operation-status))
         (t-operation (cl-ds:destructive-counterpart operation))))
   (flet ((wrapper (instance)
            (unless (slot-boundp lazy-status '%eager-status)
              (let ((eager-status
                      (nth-value 1
                                 (apply #'cl-ds:position-modification
                                        t-operation
                                        instance
                                        args))))
                (setf (access-eager-status lazy-status) eager-status)
                nil)))))
   (let* ((next-instance (make 'lazy-box-container
                               :content content
                               :operations (add-change operations #'wrapper))))
     (write-lazy-instance next-instance lazy-status)
     (values next-instance
             lazy-status))))


(defmethod cl-ds:size ((container lazy-box-container))
  (force-version container)
  (cl-ds:size (access-content container)))


(defmethod cl-ds:at ((container lazy-box-container) location)
  (force-version container)
  (cl-ds:at (access-content container) location))


(defmethod cl-ds:become-transactional ((container lazy-box-container))
  (force-version container)
  (cl-ds:become-transactional (access-content container)))


(defmethod cl-ds:become-functional ((container lazy-box-container))
  (force-version container)
  (cl-ds:become-functional (access-content container)))


(defmethod cl-ds:become-mutable ((container lazy-box-container))
  (force-version container)
  (cl-ds:become-mutable (access-content container)))


(flet ((force-status (status)
         (unless (slot-boundp status '%eager-status)
           (force-version (read-lazy-instance status)))
         (access-eager-status status)))

  (defmethod cl-ds:found ((status lazy-modification-operation-status))
    (cl-ds:found (force-status status)))

  (defmethod cl-ds:value ((status lazy-modification-operation-status))
    (cl-ds:value (force-status status))))


(defmethod cl-ds:become-lazy ((container cl-ds:fundamental-container))
  (make 'lazy-box-container
        :content (cl-ds:become-transactional container)))
