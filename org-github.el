;;; org-github.el --- Sync org tasks with github issues    -*- lexical-binding: t; -*-

;; Copyright (C) 2018,2019  Daniel Kraus

;; Author: Daniel Kraus <daniel@kraus.my>
;; Version: 0.1
;; Package-Requires: ((ghub+ "0.2.1") (emacs "25"))
;; Keywords: convenience
;; URL: https://github.com/dakra/org-github

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Warning: Package is very alpha and only for personal use.
;; Use at own risk.

;; Sync github issues to org mode tasks.
;; It reads org property "GITHUB-OWNER" and "GITHUB-NAME"
;; and then fetches the issue and converts it with pandoc to org.

;; FIXME:
;; - Set more properties in org properties drawer
;; - Make comments "nicer"
;; - Always insert TODO even when on NEXT header
;; ...

;;; Code:

(require 'ghub+)
(require 'org)
(require 'org-indent)

(defgroup org-github nil
  "org-github"
  :prefix "org-github-"
  :group 'convenience)

(defcustom org-github-default-owner nil
  "Username to use as fallback when not specified as org property."
  :type 'string
  :group 'org-github)

(defcustom org-github-default-name nil
  "Repo name to use as fallback when not specified as org property."
  :type 'string
  :group 'org-github)



(defun org-github-repo-info ()
  "Get github repo info from org properties."
  (let* ((org-properties (org-entry-properties))
         (owner (or (cdr (assoc-string "GITHUB-OWNER" org-properties)) org-github-default-owner))
         (name (or (cdr (assoc-string "GITHUB-NAME" org-properties)) org-github-default-name)))
    `((owner (login . ,owner))
      (name . ,name))))

;;;###autoload
(defun org-github-issue-to-org (issue-number)
  "Fetch github issue ISSUE-NUMBER and insert as ORG in current buffer."
  (interactive "NGithub issue number:")
  (let* ((start-point)
         (repo-info (org-github-repo-info))
         (issue (ghubp-get-repos-owner-repo-issues-number
                    repo-info `((number . ,issue-number))))
         (title (cdr (assoc 'title issue)))
         (url (cdr (assoc 'url issue)))
         (body (cdr (assoc 'body issue)))
         (repo-name (cdadr (assoc 'owner repo-info)))
         (comments (when (cdr (assoc 'comments issue))
                     (ghubp-get-repos-owner-repo-issues-number-comments
                         repo-info `((number . ,issue-number))))))
    (org-insert-todo-heading-respect-content)
    (insert title)
    (if (version< org-version "9.2")
        (with-no-warnings
          (org-set-tags-to (format ":%s_%s:" (upcase repo-name) issue-number))
          (org-set-tags-command t t))  ; realign tags
      (org-set-tags (format ":%s_%s:" (upcase repo-name) issue-number))
      (org-set-tags-command t))
    (forward-line 3)  ; Move 3 lines down to the last PROPERTIES drawer line
    (move-end-of-line 1)
    (insert (format "\n[[%s][%s]]\n"
                    url (format "#%s: %s" issue-number title)))
    (setq start-point (point))
    (insert body)
    (shell-command-on-region start-point (point) "pandoc -f gfm -t org" :replace t)
    (org-indent-refresh-maybe (point) (mark) nil)
    (when comments
      (org-insert-heading-respect-content)
      (insert "Comments\n")
      (org-do-demote)
      (setq start-point (point))
      (dolist (comment comments)
        (let* ((author (cdr (assoc 'login (cdr (assoc 'user comment)))))
               (updated_at (cdr (assoc 'updated_at comment)))
               (body (cdr (assoc 'body comment))))
          (insert (format "- *Comment from %s on %s*\n\n" author updated_at))
          (insert body)
          (insert "\n\n")))
      (shell-command-on-region start-point (point) "pandoc -f gfm -t org" :replace t)
      (org-indent-refresh-maybe (point) (mark) nil))))

(provide 'org-github)
;;; org-github.el ends here
