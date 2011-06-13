;;; gimme-bookmark.el --- GIMME's bookmark-view

;; Author: Konrad Scorciapino <scorciapino@gmail.com>
;; Keywords: XMMS2, mp3

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)


;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Code

(defvar gimme-bookmark-minimal-collection-list
  '(((0 ("reference" "All Media" "title" "All Media") nil))))
(defvar gimme-anonymous-collections gimme-bookmark-minimal-collection-list)
(defvar gimme-bookmark-name "GIMME - Bookmarks")

(defun gimme-bookmark ()
  "bookmark-view"
  (interactive)
  (gimme-send-message "(colls %s)\n" (prin1-to-string gimme-bookmark-name))
  )

(defvar gimme-bookmark-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "q") (lambda () (interactive) (kill-buffer (current-buffer))))
    (define-key map (kbd "j") 'next-line)
    (define-key map (kbd "k") 'previous-line)
    (define-key map (kbd "C-f") 'scroll-up)
    (define-key map (kbd "C-b") 'scroll-down)
    (define-key map (kbd "TAB") 'gimme-toggle-view)
    (define-key map (kbd "=") (lambda () (interactive) (gimme-vol gimme-vol-delta)))
    (define-key map (kbd "+") (lambda () (interactive) (gimme-vol gimme-vol-delta)))
    (define-key map (kbd "-") (lambda () (interactive) (gimme-vol (- gimme-vol-delta))))
    (define-key map (kbd "RET") 'gimme-bookmark-view-collection)
    (define-key map (kbd "SPC") 'gimme-bookmark-toggle-highlighting)
    (define-key map (kbd "d") 'gimme-bookmark-delete-coll)
    (define-key map (kbd "r") 'gimme-bookmark-rename-coll)
    (define-key map (kbd "S") 'gimme-bookmark-save-collection)
    (define-key map (kbd "a") 'gimme-bookmark-combine-collections)
    (define-key map (kbd "A") 'gimme-bookmark-append-to-playlist)
    map)
  "bookmark-map's keymap")

(define-derived-mode gimme-bookmark-mode fundamental-mode
  "Used on GIMME" ""
  (use-local-map gimme-bookmark-map)
  (setq mode-name "gimme-bookmark"))


;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Interactive function ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun gimme-bookmark-append-to-playlist ()
  (interactive)
  (let ((coll (or (get-text-property (point) 'coll)
                  (get-text-property (point) 'ref))))
    (when coll (gimme-send-message  "(append_coll %s)\n" (prin1-to-string coll)))))

(defun gimme-bookmark-toggle-highlighting ()
  (interactive)
  (when (or (get-text-property (point) 'coll) (get-text-property (point) 'ref))
    (unlocking-buffer
     (save-excursion
       (let* ((beg (progn (beginning-of-line) (point)))
              (end (progn (end-of-line) (1+ (point))))
              (face (get-text-property beg 'face)))
         (if (not (equal face 'highlight))
             (progn (put-text-property beg end 'oldface face)
                    (put-text-property beg end 'face 'highlight))
           (put-text-property beg end 'face
                              (get-text-property beg 'oldface))))))))

(defun gimme-bookmark-combine-collections ()
  (interactive)
  (let* ((colls (get-bounds-where
                 (lambda (x) (equal (get-text-property x 'face) 'highlight))))
         (data (mapcar (lambda (x) (or (get-text-property (car x) 'coll)
                                       (get-text-property (car x) 'ref))) colls))
         (as-strings (mapcar (lambda (x) (format " %s" (prin1-to-string x))) data)))
    (if (= (length colls) 0) (message "No collections selected!")
      (let* ((ops (if (= (length as-strings) 1) '("not") '("and" "or")))
             (op (completing-read "Combine with? " ops)))
        (if (member op ops)
            (gimme-send-message "(combine %s () (%s))\n" (prin1-to-string op)
                                (apply #'concat as-strings))
          (message "Invalid operation!"))))))

(defun gimme-bookmark-view-collection ()
  "Jumps to filter-view with the focused collection as the current"
  (interactive)
  (cond ((get-text-property (point) 'coll)
         (gimme-send-message "(pcol %s)\n"
                             (prin1-to-string (get-text-property (point) 'coll))))
        ((get-text-property (point) 'ref)
         (setq gimme-current (get-text-property (point) 'ref))
         (gimme-send-message "(pcol %s)\n"
                             (prin1-to-string (get-text-property (point) 'ref))))))

(defun gimme-bookmark-delete-coll ()
  "Deletes focused collection"
  (interactive)
  (let* ((coll (get-text-property (point) 'coll))
         (ref (get-text-property (point) 'ref))
         (buffer (get-buffer gimme-bookmark-name)))
    (if coll
        (let* ((elements (gimme-bookmark-get-children coll t))
               (bounds
                (mapcar (lambda (x) (car (get-bounds-where
                                          (lambda (y) (equal x (get-text-property y 'coll))))))
                        elements))
               (bounds (reverse bounds)))
          (setq gimme-anonymous-collections (gimme-delete-collection coll))
          (when buffer
            (gimme-on-buffer buffer
                             (dolist (x bounds) (delete-region (car x) (cadr x))))))
      (when ref (gimme-send-message "(dcol %s)\n" (prin1-to-string ref)))))
  (unless gimme-anonymous-collections 
    (setq gimme-anonymous-collections gimme-bookmark-minimal-collection-list)))

(defun gimme-bookmark-rename-coll ()
  "Renames the focused coll"
  (interactive)
  (if (get-text-property (point) 'pos)
      (let* ((old  (get-text-property (point) 'name))
             (new  (read-from-minibuffer "New name: "))
             (pos  (get-text-property (point) 'pos))
             (node (gimme-bookmark-get-node pos))
             (data (plist-put (car node) 'name new))
             (bounds (list (line-beginning-position) (line-end-position))))
        (setcar node data))
    (when (get-text-property (point) 'ref)
      (gimme-send-message "(rcol %s %s)\n"
                          (prin1-to-string (get-text-property (point) 'ref))
                          (prin1-to-string (read-from-minibuffer "New name: "))))))


(defun gimme-bookmark-save-collection ()
  "Saves the focused collection on the core"
  (interactive)
  (let* ((coll  (get-text-property (point) 'coll))
         (name (read-from-minibuffer "Save as: ")))
    (when coll (gimme-send-message (format "(savecol %s %s)\n"
                                           (prin1-to-string coll)
                                           (prin1-to-string name))))))
;;;;;;;;;
;; Aux ;;
;;;;;;;;;
;;
;; bookmark is like (plist child1 child2 ...)


(defun gimme-bookmark-colorize (text)
  (let ((asterisks (replace-regexp-in-string "^\\(\*+\\).*" "\\1" text)))
    (propertize text 'font-lock-face `(:foreground ,(color-for asterisks)))))

(defun gimme-dfs-on-colls (function &optional colls)
  "Function must have 2 arguments: The collection on a list with its children and
   the children of the parent collection"
  (loop for coll in (or colls gimme-anonymous-collections)
        collecting `(,(funcall function coll colls)
                     ,@(when (cdr coll) (gimme-dfs-on-colls function (cdr coll))))))

(defun gimme-delete-collection (target &optional colls)
  "<thunk> konr: Well, *sometimes* [delete] deletes by side effect.  In this
           case it's probably just returning the cdr of seq."
  (loop for coll in (or colls gimme-anonymous-collections)
        if (not (equal (car coll) target)) collect
        `(,(car coll) ,@(when (cdr coll)
                          (gimme-delete-collection target (cdr coll)))) end))


(defun gimme-bookmark-dfsmap (fun &optional colls flat)
  (loop for coll in (or colls gimme-anonymous-collections)
        collecting `(,(funcall fun coll)
                     ,@(when (cdr coll) (gimme-bookmark-dfsmap fun (cdr coll) flat)))
        into elements and finally return
        (if flat (apply #'append elements) elements)))

(defun gimme-bookmark-get-parents (target &optional colls stack)
  (loop for coll in (or colls gimme-anonymous-collections)
        if (equal (car coll) target) return stack
        else when (cdr coll) collect
        (gimme-bookmark-get-parents target (cdr coll) (cons (car coll) stack)) into ch
        finally return (car (remove-if #'null ch))))

(defun gimme-bookmark-get-children (target)
  (loop for child in (cdr (gimme-bookmark-get-node target gimme-anonymous-collections))
        collecting `(,(car child) ,@(mapcar #'gimme-bookmark-get-children (cdr child)))
        into elements and finally return
        (remove-if #'null (apply #'append elements))))

(defun gimme-bookmark-get-children (target &optional including-self)
  (let* ((element (list (gimme-bookmark-get-node target gimme-anonymous-collections)))
         (colls (gimme-bookmark-dfsmap (lambda (x) (car x)) element t)))
    (if including-self colls (cdr colls))))

(defun ajusta (lista)
  (if (cdr lista)
      `(,(car (ajusta lista)) ,@(cdr (ajusta lista)))
    lista))


(defun gimme-bookmark-dfs (colls &optional depth)
  (let ((depth (or depth 2)))
    (when colls
      (loop for coll in colls collecting
            (concat
             (propertize
              (gimme-bookmark-colorize
               (format "%s %s\n" (make-string depth ?*)
                       ;; getf doesn't work with strings :(
                       (loop for x = (cadar coll)
                             then (cddr x) while x
                             if (equal (car x) "title") return (cadr x)
                             finally return "Anonymous collection")))
              'coll (car coll))
             (or (gimme-bookmark-dfs (cdr coll) (1+ depth)) ""))
            into strings and finally return (apply #'concat strings)))))

(defun gimme-bookmark-get-node (node &optional nodes)
  (if (null node) nodes
    (when nodes
      (or (car (remove-if-not (lambda (x) (equal (car x) node)) nodes))
          (gimme-bookmark-get-node node (apply #'append (mapcar #'rest nodes)))))))

(defun gimme-bookmark-add-child (data parent)
  (let* ((bookmark-buffer (get-buffer gimme-bookmark-name))
         (title (loop for pair = (cadr data) then (cddr pair)
                      while pair if (string= (car pair) "title") return (cadr pair)))
         (parent (or (gimme-bookmark-get-node parent gimme-anonymous-collections)
                     (progn (gimme-bookmark-add-child parent nil)
                            (gimme-bookmark-get-node parent
                                                     gimme-anonymous-collections))))
         (children (or (cdr parent) parent)) (on-coll `((,data))))
    (if gimme-anonymous-collections
        (unless (remove-if-not 
		 (lambda (c) (and (listp c) (equal (car c) data))) children)
          (nconc children on-coll))
      (setq gimme-anonymous-collections on-coll))
    (when bookmark-buffer
      (gimme-on-buffer
       bookmark-buffer
       (let* ((pos (car (get-bounds-where
                         (lambda (x) (equal (car parent)
                                            (get-text-property x 'coll))))))
              (ast (when pos (replace-regexp-in-string
                              "^\\(\*+\\).*\n" "\\1*"
                              (buffer-substring (car pos) (cadr pos))))))
	 (set-text-properties 0 (length ast) nil ast)
         (when pos
           (goto-char (cadr pos))
           (insert (gimme-bookmark-colorize
                    (propertize (format "%s %s\n" ast title) 'coll data)))))))))

(defun gimme-bookmark-add-pos (bookmark &optional pos)
  "Returns a bookmark with a 'pos' attribute on the plist"
  (loop for p from 1 upto (1- (length bookmark))
        collecting (gimme-bookmark-add-pos (nth p bookmark) (append pos (list p)))
        into children
        finally return (cons (append (car bookmark) `(pos ,pos)) children)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Called by the ruby process ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun gimme-register-coll (coll parent)
  (unless (gimme-bookmark-get-node parent)
    (gimme-bookmark-add-child parent gimme-anonymous-collections))
  (gimme-bookmark-add-child coll parent))

(defun gimme-bookmark-colls (buffer list)
  "Prints the available collections as a bookmark"
  (let* ((list (remove-if (lambda (n) (member n '("Default" "_active"))) list))
         (list (mapcar (lambda (n) (decode-coding-string n 'utf-8)) list)))
    (gimme-on-buffer buffer
                     (kill-region 1 (point-max))
                     (insert (gimme-bookmark-colorize "* History\n"))
                     (insert (gimme-bookmark-dfs gimme-anonymous-collections))
                     (insert (gimme-bookmark-colorize "\n"))
                     (insert (gimme-bookmark-colorize (format "* Saved collections\n")))
                     (dolist (el list)
                       (insert (gimme-bookmark-colorize
                                (propertize (format "** %s\n" el) 'ref el))))
                     (gimme-bookmark-colorize "\n")
                     (gimme-bookmark-mode)
                     (run-hooks 'gimme-goto-buffer-hook)
                     (switch-to-buffer (get-buffer gimme-bookmark-name)))))

(defun gimme-coll-changed (plist)
  "Called by the braodcast functions"
  (let ((buffer (get-buffer gimme-bookmark-name))
        (type      (getf plist 'type))
        (name      (decode-coding-string (getf plist 'name) 'utf-8))
        (namespace (getf plist 'namespace))
        (newname   (decode-coding-string (or (getf plist 'newname) "") 'utf-8)))
    (when buffer
      (gimme-on-buffer
       buffer
       (case type
         ('add
          (let ((max (cadar (last (get-bounds-where
                                   (lambda (x) (get-text-property x 'ref)))))))
            (progn (run-hook-with-args 'gimme-broadcast-coll-add-hook plist)
                   (and (goto-char max)
                        (insert (gimme-bookmark-colorize
                                 (propertize (format "** %s\n" name) 'ref name)))
                        (message (format "Collection %s added!" name))))))
         ('rename
          (let ((bounds (car (get-bounds-where
                              (lambda (x) (string= name (get-text-property x 'ref)))))))
            (kill-region (car bounds) (cadr bounds))
            (goto-char (car bounds))
            (insert (propertize (format "** %s" newname) 'ref newname))))
         ('remove
          (let ((bounds (car (get-bounds-where
                              (lambda (x) (string= name (get-text-property x 'ref)))))))
            (kill-region (car bounds) (1+ (cadr bounds))))))))))

(provide 'gimme-bookmark)
;;; gimme-bookmark.el ends here