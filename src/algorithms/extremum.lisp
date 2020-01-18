(in-package #:cl-data-structures.algorithms)


(cl-ds.alg.meta:define-aggregation-function
    extremum extremum-function

  (:range fn &key key value-key)
  (:range fn &key (key #'identity) (value-key #'identity))

  (%value %fn %first-iteration %value-key)

  ((ensure-functionf value-key fn)
   (setf %fn fn
         %value-key value-key
         %first-iteration t))

  ((element)
   (cond (%first-iteration
          (setf %value element
                %first-iteration nil))
         ((not (funcall %fn
                        (funcall %value-key %value)
                        (funcall %value-key element)))
          (setf %value element))))

  (%value))
