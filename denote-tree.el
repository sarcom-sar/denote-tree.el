;;; denote-tree.el --- Visualize your notes as a tree -*- lexical-binding: t -*-

;; Copyright 2024, Sararin
;; Created: 2024-09-15 Sun
;; Version: 0.1.0
;; Keywords: convenience
;; URL: http://127.0.0.1/
;; Package-Requires: ((emacs "27.2"))

;; This file is not part of GNU Emacs.

;; denote-tree is free software: you can redistribute it and/or modify it under
;; the terms of the GNU General Public License as published by the Free Software
;; Foundation, either version 3 of the License, or (at your option) any later
;; version.

;; denote-tree is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
;; FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
;; details.

;; You should have received a copy of the GNU General Public License along with
;; denote-tree.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; denote-tree visualizes your notes as a tree.
;;
;; A       A1
;; +-B     B1
;; | '-C   C1
;; |   '-D D1
;; +-B     B2
;; | '-C   C2
;; '-B     B3
;; | +-C   C3
;; | '-C   C4
;; |   '-D D2
;; +-B     B4
;; +-B     B5

;;; Code:

(require 'denote)
(require 'org)

(defvar denote-tree--mark-tree '()
  "Tree of points in the `*denote-tree*' where nodes are.
Used directly to traverse the tree structure.")

(defvar denote-tree--visited-buffers '()
  "List of already created buffers.")

(defvar denote-tree--cyclic-buffers '()
  "List of buffers that are cyclic nodes.")

(defvar denote-tree--pointer '()
  "Node the point is at.")

(defvar denote-tree--stack '()
  "Stack of parent nodes.")

(defvar denote-tree--closure nil
  "Closure of current instance of `denote-tree--sideways-maker'.")

(defvar-keymap denote-tree-mode-map
  :parent special-mode-map
  :doc "Keymap for denote-tree-mode."
  "n" #'denote-tree-next-node
  "p" #'denote-tree-prev-node
  "f" #'denote-tree-child-node
  "b" #'denote-tree-parent-node
  "RET" #'denote-tree-enter-node)

(define-derived-mode denote-tree-mode special-mode "denote-tree"
  "Visualize your denote notes as a tree.

Denote-tree visualizes every note linked to the root note in a *denote-tree*
buffer."
  :interactive nil
  (setq denote-tree--closure
        (denote-tree--movement-maker (1- (length denote-tree--mark-tree))))
  (setq denote-tree--pointer denote-tree--mark-tree))

(defun denote-tree--movement-maker (len-list)
  (let ((pos 0)
        (len len-list)
        (val))
    (lambda (direction)
      (setq pos (+ pos direction))
      (setq val (mod pos len))
      val)))

(defun denote-tree-enter-node ()
  (interactive)
  (find-file-other-window
   (denote-get-path-by-id
    (get-text-property (point) 'denote--id))))

(defun denote-tree-child-node (&optional val)
  (interactive "p")
  (or val (setq val 1))
  (let ((total))
    (dotimes (total val)
      (when (cadr denote-tree--pointer)
        (push denote-tree--pointer denote-tree--stack)
        (setq denote-tree--pointer (cadr denote-tree--pointer))
        (setq denote-tree--closure (denote-tree--movement-maker
                                    (length (cdr (car denote-tree--stack)))))
        (goto-char (car denote-tree--pointer))))))

(defun denote-tree-parent-node (&optional val)
  (interactive "p")
  (or val (setq val 1))
  (let ((total 0))
    (dotimes (total val)
      (when denote-tree--stack
        (setq denote-tree--pointer (pop denote-tree--stack))
        (setq denote-tree--closure (denote-tree--movement-maker
                                    (length (cdr (car denote-tree--stack)))))
        (goto-char (car denote-tree--pointer))))))

(defun denote-tree-next-node (&optional val)
  (interactive "p")
  (or val (setq val 1))
  (when denote-tree--stack
    (setq denote-tree--pointer (nth (funcall denote-tree--closure val)
                                    (cdr (car denote-tree--stack))))
    (goto-char (car denote-tree--pointer))))

(defun denote-tree-prev-node (&optional val)
  (interactive "p")
  (or val (setq val 1))
  (denote-tree-next-node (- val)))

(defun denote-tree--collect-links (buffer)
  "Collect all links of type denote in BUFFER."
  (setq buffer (denote-tree--open-link-maybe buffer))
  (with-current-buffer buffer
    (org-element-map (org-element-parse-buffer) 'link
      (lambda (link)
        (when (string= (org-element-property :type link) "denote")
          (org-element-property :path link))))))

(defun denote-tree--walk-links (buffer)
  "Return a tree of denote links starting with current BUFFER."
  (let ((links-in-buffer (denote-tree--collect-links buffer)))
    (with-current-buffer buffer
      ; if no links return a buffer
      (if (null links-in-buffer)
          (list buffer)
        (let ((lst (list (denote-tree--collect-keyword buffer "identifier"))))
          ;; if links go deeper
          (dolist (el links-in-buffer lst)
            ;; this essentially checks if next node is a colored in black
            (if (and (get-buffer el)
                     (add-to-list 'denote-tree--cyclic-buffers el))
                (setq lst (append lst (list (list el))))
              (setq lst (append lst (list (denote-tree--walk-links el))))))
          lst)))))

(defun denote-tree--collect-keyword (buffer keyword)
  "Return org KEYWORD from BUFFER.
Return nil if none is found."
  (let ((collected-keyword))
    (with-current-buffer buffer
      (setq collected-keyword (org-collect-keywords (list keyword))))
    (car (cdar collected-keyword))))

(defun denote-tree--open-link-maybe (element)
  "Return ELEMENT buffer, create if necessary."
  (unless (member element denote-tree--visited-buffers)
    (add-to-list 'denote-tree--visited-buffers element)
    (get-buffer-create element)
    (with-current-buffer element
      (org-mode)
      (erase-buffer)
      (insert-file-contents (denote-get-path-by-id element))))
  element)

(defun denote-tree--clean-up ()
  "Clean up buffers created during the tree walk."
  (dolist (el denote-tree--visited-buffers)
    (kill-buffer el))
  (setq denote-tree--visited-buffers nil)
  (setq denote-tree--cyclic-buffers nil))

(defun denote-tree (&optional buffer)
  "Draw hierarchy between denote files as a tree.
The function uses either the current buffer, if called from a function
a BUFFER provided by the user."
  (interactive)
  (denote-tree--clean-up)
  (or buffer (setq buffer (denote-tree--collect-keyword (current-buffer)
                                                        "identifier")))
  (denote-tree--open-link-maybe buffer)
  (with-current-buffer-window "*denote-tree*" nil nil
      (erase-buffer)
      (denote-tree--draw-tree
       (denote-tree--walk-links buffer))))

(defun denote-tree--draw-tree (node)
  "Draw a tree in current buffer starting with NODE."
  (setq denote-tree--mark-tree
        (denote-tree--draw-tree-helper node "" t)))

;; it is /imperative/ to merge this function and
;; denote-tree--walk-links, because they do a lot
;; of similar things
(defun denote-tree--draw-tree-helper (node indent last-child)
  "Insert INDENT and current NODE into the buffer.
If dealing with LAST-CHILD of NODE, alter pretty printing."
  (let ((point-loc))
    (insert indent)
    (cond
     (last-child
      (setq indent (concat indent "  "))
      (insert "'-"))
     (t
      (setq indent (concat indent "| "))
      (insert "+-")))
    (insert "*")
    (setq point-loc (1- (point)))
    (add-text-properties point-loc (point) (list 'denote--id (car node)
                                                 'face 'button))
    (insert " " (denote-tree--collect-keyword (car node) "title") "\n")
    (let ((lst (list point-loc))
          (lastp last-child))
      (dolist (el (cdr node) lst)
        (setq lastp (equal el (car (last node))))
        (setq lst (append lst (list (denote-tree--draw-tree-helper el
                                                                   indent
                                                                   lastp)))))
      lst)))

(provide 'denote-tree)
;;; denote-tree.el ends here
