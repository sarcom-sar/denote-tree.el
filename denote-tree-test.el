;;; denote-tree-test.el --- Test denote-tree -*- lexical-binding: nil -*-

(require 'denote-tree)
(require 'ert)

(defvar denote-tree-test-mock--denote-file-types-1
  '((org
     :title-key-regexp "org-title:"
     :identifier-key-regexp "org-identifier:"
     :keywords-key-regexp "org-keywords:"
     :signature-key-regexp "org-signature:"
     :date-key-regexp "org-date:")
    (markdown-yaml
     :title-key-regexp "yaml-title:"
     :identifier-key-regexp "yaml-identifier:"
     :keywords-key-regexp "yaml-keywords:"
     :signature-key-regexp "yaml-signature:"
     :date-key-regexp "yaml-date:")
    (markdown-toml
     :title-key-regexp "toml-title:"
     :identifier-key-regexp "toml-identifier:"
     :keywords-key-regexp "toml-keywords:"
     :signature-key-regexp "toml-signature:"
     :date-key-regexp "toml-date:")
    (text
     :title-key-regexp "text-title:"
     :identifier-key-regexp "text-identifier:"
     :keywords-key-regexp "text-keywords:"
     :signature-key-regexp "text-signature:"
     :date-key-regexp "text-date:")))

(defvar denote-tree-test-mock--denote-file-types-2
  '((org
     :title-key-regexp "org-title:"
     :identifier-key-regexp "org-identifier:")
    (markdown-yaml
     :title-key-regexp "yaml-title:"
     :identifier-key-regexp "yaml-identifier:")
    (markdown-toml
     :title-key-regexp "toml-title:"
     :identifier-key-regexp "toml-identifier:")
    (text
     :title-key-regexp "text-title:"
     :identifier-key-regexp "text-identifier:")))

(ert-deftest denote-tree-test--default-props ()
  "Tests for `denote-tree--default-props'."
  (should (equal-including-properties
           (denote-tree--default-props "a" 'b)
           (propertize "a" 'denote-tree--type 'b)))
  (should (equal-including-properties
           (denote-tree--default-props "" 'b)
           (propertize "" 'denote-tree--type 'b)))
  (should (equal-including-properties
           (denote-tree--default-props "a" 'b)
           (propertize "a" 'denote-tree--type 'b)))
  (should (equal-including-properties
           (denote-tree--default-props "a" '(b c))
           (propertize "a" 'denote-tree--type '(b c)))))

(defmacro denote-tree-test--prepare-buffer-space
    (start-bufs after-bufs visited)
  "Prepare an environment for testing `denote-tree--clean-up'.

Argument START-BUFS - starting \"buffers\";
Argument AFTER-BUFS - what BUFFERS should be after the call;
Argument VISITED    - \"buffers\" to be cleaned up."
  `(let ((fake-buffers ,start-bufs)
         (denote-tree--visited-buffers ,visited)
         (denote-tree--cyclic-buffers '()))
     (cl-letf (((symbol-function 'kill-buffer)
                (lambda (thing)
                  (if (member thing fake-buffers)
                      (setq fake-buffers (remove thing fake-buffers))
                    (error "No buffer named %s" thing))))
               ((symbol-function 'get-buffer)
                (lambda (thing)
                  (member thing fake-buffers))))
       (denote-tree--clean-up)
       (should (equal fake-buffers ,after-bufs)))))

(ert-deftest denote-tree-test--clean-up ()
  "Tests for `denote-tree--clean-up'."
  (denote-tree-test--prepare-buffer-space
   '(a b c d e f) '(a b c d e f) '())
  (denote-tree-test--prepare-buffer-space
   '(a b c d e f) '(b d e f) '(c a))
  (denote-tree-test--prepare-buffer-space
   '(a b c d e f) '(a b c d e f) '(g)))

(ert-deftest denote-tree-test--collect-keywords-as-string ()
  "Tests for `denote-tree--collect-keywords-as-string'."
  (cl-letf (((symbol-function 'denote-tree--collect-keywords)
             ;; real functions returns in reverse
             (lambda (_ _)
               '((a . "a")
                 (b . "b")
                 (c . "c")))))
    (should (equal (denote-tree--collect-keywords-as-string '_ '_)
                   "c b a")))
  (cl-letf (((symbol-function 'denote-tree--collect-keywords)
             ;; real functions returns in reverse
             (lambda (_ _)
               '((a . "a")
                 (b)
                 (c . "c")))))
    (should (equal (denote-tree--collect-keywords-as-string '_ '_)
                   "c a")))
  (cl-letf (((symbol-function 'denote-tree--collect-keywords)
             ;; real functions returns in reverse
             (lambda (_ _)
               '((a)
                 (b)
                 (c . "c")))))
    (should (equal (denote-tree--collect-keywords-as-string '_ '_)
                   "c")))
  (cl-letf (((symbol-function 'denote-tree--collect-keywords)
             ;; real functions returns in reverse
             (lambda (_ _)
               '((a)
                 (b)
                 (c)))))
    (should (equal (denote-tree--collect-keywords-as-string '_ '_)
                   ""))))

(ert-deftest denote-tree-test--find-filetype ()
  "Tests for `denote-tree--find-filetype'."
  (let ((denote-file-types denote-tree-test-mock--denote-file-types-1))
    (with-temp-buffer
      (insert "org-title: title")
      (should (equal (car (denote-tree--find-filetype (current-buffer)))
                     'org)))
    (with-temp-buffer
      (insert "org-identifier: identifier")
      (should (equal (car (denote-tree--find-filetype (current-buffer)))
                     'org)))
    (with-temp-buffer
      (insert "org-keywords: keywords")
      (should (equal (car (denote-tree--find-filetype (current-buffer)))
                     'org)))
    (with-temp-buffer
      (insert "yaml-title: title")
      (should (equal (car (denote-tree--find-filetype (current-buffer)))
                     'markdown-yaml)))
    (with-temp-buffer
      (insert "yaml-identifier: identifier")
      (should (equal (car (denote-tree--find-filetype (current-buffer)))
                     'markdown-yaml)))
    (with-temp-buffer
      (insert "yaml-keywords: keywords")
      (should (equal (car (denote-tree--find-filetype (current-buffer)))
                     'markdown-yaml)))
    (with-temp-buffer
      (insert "toml-title: title")
      (should (equal (car (denote-tree--find-filetype (current-buffer)))
                     'markdown-toml)))
    (with-temp-buffer
      (insert "toml-identifier: identifier")
      (should (equal (car (denote-tree--find-filetype (current-buffer)))
                     'markdown-toml)))
    (with-temp-buffer
      (insert "toml-keywords: keywords")
      (should (equal (car (denote-tree--find-filetype (current-buffer)))
                     'markdown-toml)))
    (with-temp-buffer
      (insert "text-title: title")
      (should (equal (car (denote-tree--find-filetype (current-buffer)))
                     'text)))
    (with-temp-buffer
      (insert "text-identifier: identifier")
      (should (equal (car (denote-tree--find-filetype (current-buffer)))
                     'text)))
    (with-temp-buffer
      (insert "text-keywords: keywords")
      (should (equal (car (denote-tree--find-filetype (current-buffer)))
                     'text)))
    (with-temp-buffer
      (insert "p-title: title")
      (should (equal (car (denote-tree--find-filetype (current-buffer)))
                     nil)))
    (with-temp-buffer
      (insert "p-identifier: identifier")
      (should (equal (car (denote-tree--find-filetype (current-buffer)))
                     nil)))
    (with-temp-buffer
      (insert "p-keywords: keywords")
      (should (equal (car (denote-tree--find-filetype (current-buffer)))
                     nil)))
    (with-temp-buffer
      (insert "")
      (should (equal (car (denote-tree--find-filetype (current-buffer)))
                     nil)))))

(ert-deftest denote-tree-test--collect-keywords ()
  "Tests for `denote-tree--collect-keywords'."
  (cl-letf (((symbol-function 'denote-tree--find-filetype)
             (lambda (_)
               (assq 'org denote-tree-test-mock--denote-file-types-1))))
    (with-temp-buffer
      (insert "org-title: foo
org-identifier: bar
org-keywords: baz
org-signature: foz
org-date: fazboo
")
      (should (equal-including-properties
               (denote-tree--collect-keywords (current-buffer)
                                              '(title
                                                identifier
                                                keywords
                                                signature
                                                date))
               `((date . ,(propertize "fazboo" 'denote-tree--type 'date))
                 (signature . ,(propertize "foz" 'denote-tree--type 'signature))
                 (keywords . ,(propertize "baz" 'denote-tree--type 'keywords))
                 (identifier . ,(propertize "bar" 'denote-tree--type 'identifier))
                 (title . ,(propertize "foo" 'denote-tree--type 'title))))))
    (with-temp-buffer
      (insert "org-title: foo
org-identifier: bar
org-signature: foz
org-date: fazboo
")
      (should (equal-including-properties
               (denote-tree--collect-keywords (current-buffer)
                                              '(title
                                                identifier
                                                keywords
                                                signature
                                                date))
               `((date . ,(propertize "fazboo" 'denote-tree--type 'date))
                 (signature . ,(propertize "foz" 'denote-tree--type 'signature))
                 (keywords)
                 (identifier . ,(propertize "bar" 'denote-tree--type 'identifier))
                 (title . ,(propertize "foo" 'denote-tree--type 'title))))))
    (with-temp-buffer
      (should (equal-including-properties
               (denote-tree--collect-keywords (current-buffer)
                                              '())
               nil)))
    ;; possible extension point for future keywords
    (let ((denote-tree-test-mock--denote-file-types-1 (copy-tree denote-tree-test-mock--denote-file-types-2)))
      (setf (alist-get 'org denote-tree-test-mock--denote-file-types-1)
            (append (alist-get 'org denote-tree-test-mock--denote-file-types-1)
                    '(:kazoo-key-regexp "org-kazoo:")))
      (with-temp-buffer
        (insert "org-kazoo: PRRT")
        (should (equal-including-properties
                 (denote-tree--collect-keywords (current-buffer)
                                                '(kazoo))
                 `((kazoo . ,(propertize "PRRT" 'denote-tree--type 'kazoo)))))))))

(ert-deftest denote-tree-test--build-full-filetype ()
  "Tests for `denote-tree--build-full-filetype'."
  (let ((type (assq 'org denote-tree-test-mock--denote-file-types-1)))
    (should (equal (denote-tree--build-full-filetype type)
                   '(org
                     :title-key-regexp "org-title:"
                     :identifier-key-regexp "org-identifier:"
                     :keywords-key-regexp "org-keywords:"
                     :signature-key-regexp "org-signature:"
                     :date-key-regexp "org-date:"))))
  (let ((type (assq 'org denote-tree-test-mock--denote-file-types-2)))
    (should (equal (denote-tree--build-full-filetype type)
                   '(org
                     :title-key-regexp "org-title:"
                     :identifier-key-regexp "org-identifier:"
                     :date-key-regexp "^#\\+date\\s-*:"
                     :signature-key-regexp "^#\\+signature\\s-*:"
                     :identifier-key-regexp "^#\\+identifier\\s-*:")))))

(ert-deftest denote-tree-test--collect-links ()
  "Tests for `denote-tree--collect-links'."
  (cl-letf (((symbol-function 'denote-tree--open-link-maybe)
             (lambda (buffer)
               buffer)))
    (with-temp-buffer
      (insert "#+title: FOO
20231226T163250 20240119T164551 20240120T164558 20240121T164829 20240121T164914
20231227T163408 20231228T163736 20231229T164123 20240101T164316 20240117T164506")
      (goto-char (point-min))
      (should (equal (denote-tree--collect-links (current-buffer))
                     '("20231226T163250" "20240119T164551" "20240120T164558"
                       "20240121T164829" "20240121T164914" "20231227T163408"
                       "20231228T163736" "20231229T164123" "20240101T164316"
                       "20240117T164506"))))
    (with-temp-buffer
      (insert "#+title: FOO
#+identifier: 20231226T163250

20240119T164551 20240120T164558")
      (goto-char (point-min))
      (should (equal (denote-tree--collect-links (current-buffer))
                     '("20240119T164551" "20240120T164558"))))
    (with-temp-buffer
      (insert "#+title: FOO
#+identifier: 20231226T163250")
      (goto-char (point-min))
      (should (equal (denote-tree--collect-links (current-buffer))
                     nil)))
    (with-temp-buffer
      (insert "#+identifier: 20231226T163250")
      (goto-char (point-min))
      (should (equal (denote-tree--collect-links (current-buffer))
                     nil)))))

(ert-deftest denote-tree-test--extract-and-compare-symbols ()
  "Tests for `denote-tree--extract-and-compare-symbols'."
  (should (eq (denote-tree--extract-and-compare-symbols
               :title-key-regexp 'title)
              :title-key-regexp))
  (should (eq (denote-tree--extract-and-compare-symbols
               'title-key-regexp 'title)
              nil))
  (should (eq (denote-tree--extract-and-compare-symbols
               :date-format 'date)
              nil))
  (should (eq (denote-tree--extract-and-compare-symbols
               :foo-bar-baz-regexp 'foo)
              :foo-bar-baz-regexp))
  (should (eq (denote-tree--extract-and-compare-symbols
               :foobar-regexp 'foobar)
              :foobar-regexp))
  (should (eq (denote-tree--extract-and-compare-symbols
               :foo-regexp nil)
              nil))
  (should (eq (denote-tree--extract-and-compare-symbols
               nil 'bar)
              nil)))

(ert-deftest denote-tree-test--get-regexps ()
  "Tests for `denote-tree--get-regexps'."
  (should (equal (denote-tree--get-regexps '())
                 '()))
  (should (equal (denote-tree--get-regexps '("foor" "baz"))
                 '()))
  (should (equal (denote-tree--get-regexps '(:foo-regexp "foor"
                                             :bar-regexp bar))
                 '(:foo-regexp)))
  (should (equal (denote-tree--get-regexps '(:foo-regexp "foor"
                                             :bar "bar"))
                 '(:foo-regexp)))
  (should (equal (denote-tree--get-regexps '(:foo-regexp "foor"
                                             :bar-regexp "baar"))
                 '(:bar-regexp :foo-regexp))))

(ert-deftest denote-tree-test--add-props-to-children ()
  "Tests for `denote-tree--add-props-to-children'."
  (should (equal (denote-tree--add-props-to-children '() '())
                 nil))
  (with-temp-buffer
    (insert "'-* A
  '-* B")
    (goto-char (point-min))
    (denote-tree--add-props-to-children '(7) 1)
    (let ((props (text-properties-at 1)))
      (setq props (mapcar (lambda (x) (if (markerp x) (marker-position x) x))
                          props))
      (should (equal props
                     '(denote-tree--child 7))))
    (let ((props (text-properties-at 7)))
      (setq props (mapcar (lambda (x) (if (markerp x) (marker-position x) x))
                          props))
      (should (equal props
                     '( denote-tree--parent 1
                        denote-tree--prev 7
                        denote-tree--next 7)))))
  (with-temp-buffer
    (insert "A
 B
 B
 B
 B")
    (goto-char (point-min))
    (denote-tree--add-props-to-children '(4 7 10 13) 1)
    (let ((props (text-properties-at 1)))
      (setq props (mapcar (lambda (x) (if (markerp x) (marker-position x) x))
                          props))
      (should (equal props
                     '(denote-tree--child 4))))
    (let ((props (text-properties-at 4)))
      (setq props (mapcar (lambda (x) (if (markerp x) (marker-position x) x))
                          props))
      (should (equal props
                     '( denote-tree--parent 1
                        denote-tree--prev 13
                        denote-tree--next 7)))))
  (with-temp-buffer
    (insert " A
 B
C
 B
 B")
    (goto-char (point-min))
    (denote-tree--add-props-to-children '(2 4 10 13) 7)
    (let ((props (text-properties-at 7)))
      (setq props (mapcar (lambda (x) (if (markerp x) (marker-position x) x))
                          props))
      (should (equal props
                     '(denote-tree--child 2))))
    (let ((props (text-properties-at 2)))
      (setq props (mapcar (lambda (x) (if (markerp x) (marker-position x) x))
                          props))
      (should (equal props
                     '( denote-tree--parent 7
                        denote-tree--prev 13
                        denote-tree--next 4)))))
  (should (equal (denote-tree--add-props-to-children '(4 5 6) nil)
                 nil)))

(defmacro denote-tree-test-mock--draw-node-macro (properties cyclic &rest body)
  "Execute BODY with denote-tree--cyclic-buffers set to CYCLIC and
denote-tree--collect-keywords-as-string set to return PROPERTIES."
  (declare (indent 2))
  `(cl-letf (((symbol-function 'denote-tree--collect-keywords-as-string)
              (lambda (_ _)
                (concat ,@properties))))
     (let ((denote-tree--cyclic-buffers ,cyclic))
       (with-temp-buffer
         ,@body))))

(ert-deftest denote-tree-test-properties--draw-node ()
  "Tests of changed properties for `denote-tree--draw-node'."
  (denote-tree-test-mock--draw-node-macro
      ((propertize "A" 'denote-tree--type 'a))
      nil
    (denote-tree--draw-node "name" "" t)
    (should (equal (text-properties-at 3)
                   '(face denote-tree-node)))
    (should (equal (text-properties-at 5)
                   '(denote-tree--type a))))
  (denote-tree-test-mock--draw-node-macro
      ((propertize "A" 'denote-tree--type 'a))
      nil
    (denote-tree--draw-node "name" "   " t)
    (should (equal (text-properties-at 8)
                   '(denote-tree--type a))))
  (denote-tree-test-mock--draw-node-macro
      nil
      nil
    (should-error (denote-tree--draw-node nil nil nil)))
  (denote-tree-test-mock--draw-node-macro
      ((propertize "A " 'denote-tree--type 'a)
       (propertize "B" 'denote-tree--type 'b))
      nil
    (denote-tree--draw-node "name" "" t)
    (should (equal (text-properties-at 3)
                   '(face denote-tree-node)))
    (should (equal (text-properties-at 5)
                   '(denote-tree--type a)))
    (should (equal (text-properties-at 7)
                   '(denote-tree--type b))))
  (denote-tree-test-mock--draw-node-macro
      ((propertize "A " 'denote-tree--type 'a)
       (propertize "B" 'denote-tree--type 'b))
      '(("name" 3 5))
    (denote-tree--draw-node "name" "" t)
    (should (equal (text-properties-at 3)
                   '(face denote-tree-circular-node)))
    (should (equal (text-properties-at 5)
                   '(denote-tree--type a)))
    (should (equal (text-properties-at 7)
                   '(denote-tree--type b))))
  (denote-tree-test-mock--draw-node-macro
      nil
      nil
    (denote-tree--draw-node "name" "" nil)
    (should (equal (text-properties-at 5)
                   nil))))

(ert-deftest denote-tree-test-ret--draw-node ()
  "Tests of return values for `denote-tree--draw-node'."
  (denote-tree-test-mock--draw-node-macro
      ((propertize "A" 'denote-tree--type 'a))
      nil
    (let ((ret-val (denote-tree--draw-node "name" "" nil)))
      (goto-char 3)
      (should (equal ret-val
                     (cons (point-marker) "| ")))))
  (denote-tree-test-mock--draw-node-macro
      ((propertize "A" 'denote-tree--type 'a))
      nil
    (let ((ret-val (denote-tree--draw-node "name" "| | |" nil)))
      (goto-char 8)
      (should (equal ret-val
                     (cons (point-marker) "| | || ")))))
  (denote-tree-test-mock--draw-node-macro
      ((propertize "A" 'denote-tree--type 'a))
      nil
    (let ((ret-val (denote-tree--draw-node "name" "" t)))
      (goto-char 3)
      (should (equal ret-val
                     (cons (point-marker) "  "))))))

(ert-deftest denote-tree-test--add-props-to-cycles ()
  "Tests for `denote-tree--add-props-to-children'."
  (let ((denote-tree--cyclic-buffers nil))
    (with-temp-buffer
      (insert (propertize "* " 'button-data "name"))
      (denote-tree--add-props-to-cycles)
      (should (equal (text-properties-at 1)
                     '(button-data "name")))))
  (let ((denote-tree--cyclic-buffers '(("name" 22))))
    (with-temp-buffer
      (insert "'-"
              (propertize "* " 'button-data "name" 'denote-tree--child 10)
              "A\n"
              "  '-"
              (propertize "* " 'button-data "eman" 'denote-tree--child 22)
              "B\n"
              "     '-"
              (propertize "* " 'button-data "name"))
      (goto-char (point-min))
      (denote-tree--add-props-to-cycles)
      (let ((pos (marker-position
                  (get-text-property 22 'denote-tree--child))))
        (should (equal pos
                       10)))))
  (let ((denote-tree--cyclic-buffers '(("name" 14 20))))
    (with-temp-buffer
      (insert "-"
              (propertize "* " 'button-data "name" 'denote-tree--child 8)
              "A1\n "
              (propertize "* " 'button-data "eman" 'denote-tree--child 19)
              "B1\n  "
              (propertize "* " 'button-data "name" 'denote-tree--child nil)
              "A2\n "
              (propertize "* " 'button-data "name")
              "A3\n")
      (goto-char (point-min))
      (denote-tree--add-props-to-cycles)
      (let ((pos (marker-position
                  (get-text-property 15 'denote-tree--child))))
        (should (equal pos
                       8)))
      (let ((pos (marker-position
                  (get-text-property 21 'denote-tree--child))))
        (should (equal pos
                       8)))))
  (let ((denote-tree--cyclic-buffers '(("name" 7))))
    (with-temp-buffer
      (insert "-"
              (propertize "* " 'button-data "foo")
              "B\n "
              (propertize "* " 'button-data "name")
              "A\n")
      (goto-char (point-min))
      (denote-tree--add-props-to-cycles)
      (let ((pos (marker-position
                  (get-text-property 7 'denote-tree--child))))
        (should (equal pos
                       nil)))))
  (let ((denote-tree--cyclic-buffers '(("name" 7))))
    (with-temp-buffer
      (insert "-"
              (propertize "* " 'button-data "foo")
              "B\n "
              (propertize "* " 'button-data "name" 'denote-tree--child 7)
              "A\n")
      (goto-char (point-min))
      (denote-tree--add-props-to-cycles)
      (let ((pos (marker-position
                    (get-text-property 7 'denote-tree--child))))
        (should (equal pos
                       7))))))

(ert-deftest denote-tree-test--open-link-maybe ()
  "Tests for `denote-tree--open-link-maybe'."
  (cl-letf (((symbol-function 'get-buffer)
             (lambda (x)
               t)))
    (should (string= (denote-tree--open-link-maybe "foo")
                     "foo")))
    (with-temp-buffer
      (cl-letf (((symbol-function 'get-buffer)
                 (lambda (x)
                   nil))
                ((symbol-function 'get-buffer-create)
                 (lambda (x)
                   (current-buffer)))
                ((symbol-function 'insert-file-contents)
                 (lambda (x)
                   (insert "foo"))))
        (let ((denote-tree--visited-buffers nil))
          (denote-tree--open-link-maybe "foo")
          (should (equal denote-tree--visited-buffers
                         '("foo"))))
        (erase-buffer)
        (let ((denote-tree--visited-buffers '("foo")))
          (denote-tree--open-link-maybe "foo")
          (should (equal denote-tree--visited-buffers
                         '("foo")))))))

(defvar denote-tree-test-mock-next-links nil)
(defun denote-tree-test-mock-make-next-links (lst-of-links)
  (let ((x lst-of-links))
    (setq denote-tree-test-mock-next-links
          (lambda ()
            (prog1
                x
              (setq x (cdr x)))))))

(defmacro denote-tree-test-mock--walk-links-macro
    (cyc-bufs lst-of-links &rest body)
  ""
  (declare (indent 2))
  ;; ugly by hand check
  `(let ((denote-tree--cyclic-buffers ,cyc-bufs)
         (denote-tree--visited-buffers nil))
     (denote-tree-test-mock-make-next-links ,lst-of-links)
     (cl-letf (((symbol-function 'denote-tree--collect-links)
                (lambda (x)
                  (let ((y (funcall denote-tree-test-mock-next-links)))
                    (car y))))
               ((symbol-function 'denote-tree--collect-keywords-as-string)
                (lambda (x y)
                  (propertize x
                              'denote-tree--type
                              'title))))
       ,@body)))

(ert-deftest denote-tree-test-draw--walk-links ()
  "Tests for how `denote-tree--walk-links' draws."
  (with-temp-buffer
    (denote-tree-test-mock--walk-links-macro
        nil
        '(("a"))
      (denote-tree--walk-links (buffer-name (current-buffer)) "" t t)
      (should (string= (buffer-substring-no-properties (point-min)
                                                       (point-max))
                       (concat "'-* " (buffer-name (current-buffer)) "\n"
                               "  '-* a\n")))))
  (with-temp-buffer
    (denote-tree-test-mock--walk-links-macro
        nil
        '(("a") ("b" "c" "d"))
      (denote-tree--walk-links (buffer-name (current-buffer)) "" t t)
      (should (string= (buffer-substring-no-properties (point-min)
                                                       (point-max))
                       (concat "'-* "  (buffer-name (current-buffer)) "\n"
                               "  '-* a\n"
                               "    +-* b\n"
                               "    +-* c\n"
                               "    '-* d\n")))))
  (with-temp-buffer
    (denote-tree-test-mock--walk-links-macro
        nil
        '(("a") ("b" "c" "d") () ("e" "f"))
      (denote-tree--walk-links (buffer-name (current-buffer)) "" t t)
      (should (string= (buffer-substring-no-properties (point-min)
                                                       (point-max))
                       (concat "'-* " (buffer-name (current-buffer)) "\n"
                               "  '-* a\n"
                               "    +-* b\n"
                               "    +-* c\n"
                               "    | +-* e\n"
                               "    | '-* f\n"
                               "    '-* d\n")))))
  (with-temp-buffer
    (denote-tree-test-mock--walk-links-macro
        '(("a"))
        '(("a") ("b" "c" "d" "a"))
      (denote-tree--walk-links (buffer-name (current-buffer)) "" t t)
      (should (string= (buffer-substring-no-properties (point-min)
                                                       (point-max))
                       (concat "'-* " (buffer-name (current-buffer)) "\n"
                               "  '-* a\n"))))))

(provide 'denote-tree-test)
