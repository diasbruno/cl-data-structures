(cl:in-package #:cl-data-structures.file-system)


(defclass command ()
  ((%command-string :type string
                    :initarg :command-string
                    :reader read-command-string)))


(defmethod print-object ((object command) stream)
  (print-unreadable-object (object stream)
    (format stream "~a" (read-command-string object))))


(defmethod stream-designator-p ((designator command))
  t)


(defmethod open-stream-designator ((designator command))
  (~> designator read-command-string
      (uiop:launch-program :output :stream :force-shell t)
      uiop/launch-program:process-info-output))


(defun command (format-control-string &rest format-arguments)
  (declare (dynamic-extent format-arguments))
  (check-type format-control-string string)
  (make 'command
        :command-string (apply #'format nil
                               format-control-string format-arguments)))
