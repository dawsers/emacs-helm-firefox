;;; helm-firefox.el --- Firefox bookmarks and history -*- lexical-binding: t -*-

;; Copyright (C) 2019 dawser <dawser@none.none>

;; Version: 1.0
;; Package-Requires: ((helm "1.5") (cl-lib "0.5") (emacs "24.1"))
;; URL: https://github.com/dawsers/emacs-helm-firefox

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.


;;; Code:
(require 'cl-lib)
(require 'helm)

(defgroup helm-firefox nil
  "Helm libraries and applications for Firefox navigator."
  :group 'helm)

(defcustom helm-firefox-default-database
  (expand-file-name (car (file-expand-wildcards "~/.mozilla/firefox/*.default*/places.sqlite")))
  "Specify database name, On MacOS, profile directory is probably \"~/Library/Application Support/Firefox/\"."
  :group 'helm-firefox
  :type 'string)

(defvar helm-firefox--bookmarks-sql-query
  "SELECT c.title AS Parent, a.title AS Title, b.url AS URL, DATETIME(a.dateAdded/1000000,'unixepoch') AS DateAdded FROM moz_bookmarks AS a JOIN moz_places AS b ON a.fk = b.id, moz_bookmarks AS c WHERE a.parent = c.id")

(defvar helm-firefox--history-sql-query
  "SELECT b.title AS Title, b.url AS URL, DATETIME(a.visit_date/1000000,'unixepoch') AS DateAdded FROM moz_historyvisits AS a JOIN moz_places AS b ON b.id = a.place_id")

(defun helm-firefox--transform-bookmarks-sql-result ()
  "Parse the output from `sqlite3' in ascii mode."
  (goto-char (point-min))
  (let (result)
    (while (re-search-forward (rx (group (+? any)) (eval (kbd "C-^"))) nil t)
      (push (split-string (match-string 1) (kbd "C-_")) result))
    (mapcar (pcase-lambda (`(,parent ,title ,url ,date))
              (let ((date-str (format "%s" date)))
                (cons (concat (propertize date-str 'face 'bold) ": " parent "/" title " = " url) url)))
            result)))

(defun helm-firefox--transform-history-sql-result ()
  "Parse the output from `sqlite3' in ascii mode."
  (goto-char (point-min))
  (let (result)
    (while (re-search-forward (rx (group (+? any)) (eval (kbd "C-^"))) nil t)
      (push (split-string (match-string 1) (kbd "C-_")) result))
    (mapcar (pcase-lambda (`(,title ,url ,date))
              (let ((date-str (format "%s" date)))
                (cons (concat (propertize date-str 'face 'bold) ": " title " = " url) url)))
            result)))

(defun helm-firefox--make-sources (name sql-query transformer)
  "Make a `helm' source of NAME with SQL-QUERY and TRANSFORMER."
  (helm-build-sync-source name
    :candidates
    (let ((buf (generate-new-buffer "*helm-firefox sqlite*")))
      (with-current-buffer buf
        (let* ((db-path (make-temp-file "helm-firefox-database"))
               (query-cmd sql-query)
               result)
          (condition-case nil
              (copy-file helm-firefox-default-database db-path t)
            (error "Could not copy Firefox database"))
          (if (zerop (call-process "sqlite3" nil (current-buffer) nil
                                   "-ascii" db-path query-cmd))
              (unwind-protect
                  (setq result (funcall transformer))
                (kill-buffer buf)
                (delete-file db-path)
                result)
            (pop-to-buffer buf)
            (error "SQLite exited with error")))))
    :action '(("Browse URL" . browse-url) ("Copy URL" . kill-new))))

;;;###autoload
(defun helm-firefox-bookmarks ()
  "Preconfigured `helm' for Firefox bookmarks."
  (interactive)
  (helm :sources (helm-firefox--make-sources
                  "Firefox Bookmarks"
                  helm-firefox--bookmarks-sql-query
                  'helm-firefox--transform-bookmarks-sql-result)
        :buffer "*Helm Firefox*"))

;;;###autoload
(defun helm-firefox-history ()
  "Preconfigured `helm' for Firefox history."
  (interactive)
  (helm :sources (helm-firefox--make-sources
                  "Firefox History"
                  helm-firefox--history-sql-query
                  'helm-firefox--transform-history-sql-result)
        :buffer "*Helm Firefox*"))

(provide 'helm-firefox)

;; Local Variables:
;; byte-compile-warnings: (not cl-functions obsolete)
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:

;;; helm-firefox.el ends here
