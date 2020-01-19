(cl:in-package #:cl-data-structures.metric-space)


(defgeneric distance (container bucket element)
  (:method ((container metric-space-set)
            (bucket t)
            (element t))
    (funcall (read-metric-fn container) bucket element)))


(defmethod cl-ds.meta:make-bucket ((operation t)
                                   (container metric-space-set)
                                   location
                                   &rest all)
  (declare (ignore all))
  (values (cl-ds:force location)
          (cl-ds.common:make-eager-modification-operation-status nil nil t)))
