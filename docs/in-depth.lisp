(in-package #:cl-data-structures.documentation)
(cl-lore.api.syntax:syntax
 cl-lore.extensions.documentation.api
 cl-lore.extensions.sequence-graphs.api)


(with-names (cl-lore.extensions.documentation.api:<documentation-names>)
  (chunk *cl-data-structures*
    (level [section] @label{cl-ds internals}
      @title{Internal details}
      [:text This section explains parts of system design and low-level elements that shouldn't bother user of the library.  However, they are critical for contributors, and some people just want to know and so shall be delivered.]
      (level [section]
        @title{Docstrings and docstample}
        [:text Majority of docstrings are constructed and set outside function definitions, in a separate file. This has been done in such way to not clutter the code with information that is easy to obtain by any SLIME user. Furthermore this allows to build doctsrings with the code itself. This makes easier to ensure common, uniform style of docstrings. It may also perform various operations on docstrings. To handle this, a separate project called docstample was created. Hopefully, this tool can be augmented in the future to handle tasks such as automatic validation of examples. This is in fact what is done in this project. Examples are written as unit tests, so they can be checked if they actually work (so users are not getting angry, hopefully). Also, building docstrings from structured input eliminates need for parsing (a language other than lisp itself) to build a nicely formatted output (which is nice).])

      (level [section]
        @title{POSITION-MODIFICATION metaprotocol}
        [:text The package defines its own internal object protocol that is used to build parts of user API responsible for container modifications. This concept is nicknamed position-modification metaprotocol and is described in this section.]
        [:text As every object protocol, position-modification metaprotocol consists of classes and generic functions that are expected to be implemented for said classes. Those functions are designed to peform low level (that is: dependent on the internals structure) operations on containers. For instance, those operations include manipulations (and construction) of buckets (and "bucket" is obviously low level term used in description of data structure).]
        [:text Layer as a whole, derive it's name from one particular generic function called POSITION-MODIFICATION. It acts as a point of implementation for all functionality releated to modification of containers and therefore is called directly by functions like INSERT. Methods implementing POSITION-MODIFICATION act by calling other functions of this protocol.]

        (sequence-graph
         '("User" "API function" "POSITION-MODIFICATION")
         (seq
          :block
          '(:axis-name "User")
          (seq
           :sync
           '(:axis-name "API function" :name "User modifies instance")
           (seq
            :block
            '(:axis-name "API function")
            (seq
             :sync
             '(:axis-name "POSITION-MODIFICATION" :name "Implementation of CL-DATA-STRUCTURES")
             (seq :block '(:axis-name "POSITION-MODIFICATION")))))))

        [:text POSITION-MODIFICATION accepts OPERATION as a first argument. OPERATION is an object of one of protocol classes FUNCTIONAL-FUNCTION or DESTRUCTIVE-FUNCTION. Objects of those classes include generic functions defined as part of the API. This is made possible by the fact that Generic Functions in ,(lisp) are in fact objects of their own classes. In addition to those fundamental classes, protocol contains additional trait classes like for instance the GROW-FUNCTION. Because of this, it is possible to query API functions for expected behavior. It also makes possible to write methods that dispatch on the behavior of the API functions. These include (as already established) bucket manipulation functions: SHRINK-BUCKET, GROW-BUCKET, MAKE-BUCKET.]
        [:text Because all of those functions are generic; and just like POSITION-MODIFICATION they accept OPERATION argument, it is possible to dispatch bucket modification logic, based on the class of the API function. Employing this approach allows to remove code duplication between various types of modification functions, and therefore reduce the burden of supporting functions like ERASE-IF in the codebase. Furthermore, establishing this protocol allows to alter standard behavior of buckets, and by that, create nested data structures.]
        [:text Nested data structures are a nontrivial problem when immutable behavior is expected. In most cases, immutability is achieved by using copy-on-write semantics. Because copying in nested structures has to happen on multiple levels, It is essential to be able to intercept logic at the lower level of the data structure. Luckily, as described ,(lisp) offers tools that allowed us to build an elegant solution for such problem.]

        (level [section]
          [:title Generic Functions]
          (level [documentation]
            [:pack CL-DATA-STRUCTURES]
            @docgeneric['cl-ds:position-modification]
            @docgeneric['cl-ds:make-bucket]
            @docgeneric['cl-ds:grow-bucket]
            @docgeneric['cl-ds:shrink-bucket]
            @docgeneric['cl-ds:grow-bucket!]
            @docgeneric['cl-ds:shrink-bucket!]
            @docgeneric['cl-ds:functional-counterpart]
            @docgeneric['cl-ds:destructive-counterpart]
            ))

        (level [section]
          @title{Classes}
          (level [documentation]
            [:pack CL-DATA-STRUCTURES]
            @docclass['cl-ds:functional-function]
            @docclass['cl-ds:destructive-function]
            @docclass['cl-ds:shrink-function]
            @docclass['cl-ds:grow-function]
            @docclass['cl-ds:insert-function]
            @docclass['cl-ds:update-function]
            @docclass['cl-ds:add-function]
            @docclass['cl-ds:erase-function]
            @docclass['cl-ds:erase-if-function]
            @docclass['cl-ds:functional-insert-function]
            @docclass['cl-ds:functional-update-function]
            @docclass['cl-ds:functional-add-function]
            @docclass['cl-ds:functional-erase-function]
            @docclass['cl-ds:functional-erase-if-function]
            @docclass['cl-ds:insert!-function]
            @docclass['cl-ds:update!-function]
            @docclass['cl-ds:add!-function]
            @docclass['cl-ds:erase!-function]
            @docclass['cl-ds:erase-if!-function]
            )))
      (level [section]
        [:title Lazy evaluation]
        [:text This system offers the lazy-evaluated containers. Lazy evaluation is useful primarily because eager functional data structures may have somewhat sluggish performance if multiple, full copy-on-write operations have to be performed when inserting or erasing a large number of records from the container. Lazy evaluation allows to hide destructive operations behind the functional interface, and therefore help to counter this issue. The effectiveness of this technique varies greatly, and depends on both internal structures of the container, as well it's current content. However, what remains constant is the approach used in the implementation of lazy evaluation in this library.]
        [:text As already established in the Overview section, this library contains transactional variants of some of the data structures. Because transactional data structures form a wall isolating destructive changes, they can be used for the internal parts of the lazy evaluation style optimization. Now, the other part of the recipe is to build a functional interface around the transactional instance. This essentially requires us to use to proxy objects that will fully adapt mutable interface into the functional interface. Because of a symmetric design of the containers API, each destructive function has also functional counterpart. This makes the task fairly easy.]
        [:text To translate functional API function calls into mutable calls, a new class called LAZY-BOX-CONTAINER is introduced. LAZY-BOX-CONTAINER is holding the transactional instance of container alongside the CHANGES instance. All functional variants of API functions applicable to the internal instance, are applicable to the LAZY-BOX-CONTAINER instance as well and return values consistent with the documentation. This is done by either manually implementing methods to work on LAZY-BOX-CONTAINER (this is the case for all query functions) or by intercepting internal low-level mechanisms of position modification metaprotocol (the case for all modification functions). In other words, the LAZY-BOX-CONTAINER is (according to the design patterns terminology) a proxy. By implementing this interface, it becomes possible to capture and enclose all modification calls in closures that can be executed later. Each time POSITION-MODIFICATION method for LAZY-BOX-CONTAINER is called a new instance of the LAZY-BOX-CONTAINER with an additional closure (as well as a reference to the previous closures) and the isolated transactional instance is getting created and passed to the user. Now, the question arises: when it is required to call closures on the internal container?]
        [:text The answer to this question is simple: cl-data-structures will call the closures only when user will query the state of the container. This will in turn destructively change the internal container, however because of transactional semantics, changes will not leak outside. Finally, the query can be finished by forwarding call to the freshly transformed internal container. At this point closures in the LAZY-BOX-CONTAINER can be discarded, as changes have been fully transferred to the state of the internal container. This creates the illusion of a fully functional interface while minimizing the cost of the copy-on-write procedure.]
        [:text To summarise: lazy evaluation of the data structures is taken care of as long as a transactional variant of the data structure is available.]
        ))))
