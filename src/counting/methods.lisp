(in-package #:cl-data-structures.counting)


(defmethod type-count ((index apriori-index))
  (~> index access-reverse-mapping length))


(defmethod type-count ((node apriori-node))
  (iterate
    (for i from 0)
    (for n
         initially node
         then (read-parent n))
    (for type = (read-type n))
    (while type)
    (finally (return i))))


(defmethod type-count ((set apriori-set))
  (type-count (read-node set)))


(defmethod type-count ((set empty-mixin))
  0)


(defmethod association-frequency ((node apriori-node))
  (if-let ((parent (read-parent node)))
    (/ (read-count node) (read-count parent))
    1))


(defmethod association-frequency ((set apriori-set))
  (/ (~> set read-node read-count)
     (~> set read-apriori-node read-count)))


(defmethod association-frequency ((set empty-apriori-set))
  0)


(defmethod find-association ((index apriori-index)
                             (apriori list)
                             (aposteriori list))
  (assert apriori)
  (assert aposteriori)
  (let ((aposteriori (~> (add-to-list apriori aposteriori)
                         (remove-duplicates :test #'equal))))
    (if-let ((aposteriori aposteriori)
             (node (apply #'node-at-names index aposteriori))
             (apriori-node (apply #'node-at-names index apriori)))
      (make 'apriori-set
            :apriori-node apriori-node
            :node node
            :index index)
      (make 'empty-apriori-set :index index))))


(defmethod all-sets ((index apriori-index) minimal-frequency)
  (data-range index
              minimal-frequency
              (lambda (x)
                (make-instance 'set-in-index
                               :index index
                               :node x))))


(defmethod total-entropy ((index apriori-index))
  (entropy-from-node (read-parent index)))


(defmethod all-super-sets ((set empty-mixin) minimal-frequency)
  (all-sets (read-index set) minimal-frequency))


(defmethod all-super-sets ((set apriori-set) minimal-frequency)
  (let ((index (read-index set))
        (node (read-node set)))
    (cl-ds:xpr (:stack (list (list* (chain-node node)
                                    (read-root index))))
      (let ((cell (pop stack)))
        (when cell
          (bind (((chain . parent) cell)
                 (front (first chain))
                 (content (read-sets parent))
                 (index (lower-bound content (read-type front)
                                     #'< :key #'read-type)))
            (cond ((= index (length content))
                   (recur :stack stack))
                  ((eql (read-type front) (~> content (aref index) read-type))
                   (if (endp (rest chain))
                       (if (< (association-frequency node)
                              minimal-frequency)
                           (recur :stack stack)
                           (send-recur (make
                                        'apriori-set
                                        :node (aref content index)
                                        :index index)
                                       :stack stack))
                       (recur :stack (cons (list* (rest chain)
                                                  (aref content index))
                                           stack))))
                  (t
                   (iterate
                     (for i from 0 below index)
                     (push (list chain (aref content i)) stack)
                     (finally (recur :stack stack)))))))))))


(defmethod association-information-gain ((set apriori-set))
  (let* ((index (read-index set))
         (without-node (~> (just-post (read-apriori-node set) (read-node set))
                           (map 'list #'read-type _)
                           (apply #'node-at index)))
         (total-frequency (/ (read-count without-node)
                             (read-total-size index)))
         (total-entropy (- (* total-frequency (log total-frequency 2))))
         (yes-frequency (association-frequency set))
         (no-frequency (- 1 yes-frequency))
         (yes-entropy (- (* yes-frequency (log yes-frequency 2))))
         (no-entropy (* no-frequency (log no-frequency 2)))
         (total-size (read-total-size set)))
    (/ (- (* total-size total-entropy)
          (* (~> set read-apriori-node read-count)
             (+ yes-entropy no-entropy)))
       total-size)))


(defmethod content ((set set-in-index))
  (~>> set
       read-node
       chain-node
       (mapcar (curry #'node-name (read-index set)))))


(defmethod aposteriori-set ((set apriori-set))
  (let ((types (~>> (just-post (read-node set) (read-apriori-node set))
                    (map 'list #'read-type))))
    (make 'set-in-index
          :node (apply #'node-at-type (read-index set) types)
          :index (read-index set))))


(defmethod apriori-set ((set apriori-set))
  (make 'set-in-index
        :node (read-apriori-node set)
        :index (read-index set)))


(defmethod make-apriori-set ((apriori set-in-index)
                             (aposteriori set-in-index))
  (assert (eq (read-index apriori) (read-index aposteriori)))
  (let* ((apriori-node (read-node apriori))
         (aposteriori-node (read-node aposteriori))
         (union (~>> (add-to-list (chain-node apriori-node)
                                  (chain-node aposteriori-node))
                    (mapcar #'read-type)
                    remove-duplicates
                    (apply #'node-at (read-index apriori)))))
    (or (and union
             (make 'apriori-set
                   :index (read-index apriori)
                   :node union
                   :apriori-node apriori-node))
        (make 'empty-apriori-set :index (read-index apriori)))))


(defmethod make-apriori-set ((apriori empty-mixin)
                             (aposteriori empty-mixin))
  apriori)


(defmethod make-apriori-set ((apriori set-in-index)
                             (aposteriori empty-mixin))
  apriori)


(defmethod make-apriori-set ((apriori empty-mixin)
                             (aposteriori set-in-index))
  aposteriori)


(defmethod support ((object empty-mixin))
  0)


(defmethod support ((object apriori-index))
  (read-total-size object))


(defmethod support ((object set-in-index))
  (support (read-node object)))


(defmethod support ((object apriori-node))
  (read-count object))


(defmethod find-set ((index apriori-index) &rest content)
  (if-let ((node (apply #'node-at-names index content)))
    (make 'set-in-index
          :node node
          :index index)
    (make 'empty-set-in-index :index index)))
