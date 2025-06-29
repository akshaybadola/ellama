;;; ellama-transient.el --- Transient menus for ellama -*- lexical-binding: t; package-lint-main-file: "ellama.el"; -*-

;; Copyright (C) 2023-2025  Free Software Foundation, Inc.

;; Author: Sergey Kostyaev <sskostyaev@gmail.com>
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Ellama is a tool for interacting with large language models from Emacs.
;; It allows you to ask questions and receive responses from the
;; LLMs.  Ellama can perform various tasks such as translation, code
;; review, summarization, enhancing grammar/spelling or wording and
;; more through the Emacs interface.  Ellama natively supports streaming
;; output, making it effortless to use with your preferred text editor.
;;

;;; Code:
(require 'ellama)
(require 'transient)
(require 'ellama-context)

(defcustom ellama-transient-system-show-limit 45
  "Maximum length of system message to show."
  :type 'ingeger
  :group 'ellama)

(defvar ellama-use-ollama-p nil
  "Avoid ollama don't exist errors in the transient main menu.")
(defvar ellama-transient-ollama-model-name "")
(defvar ellama-transient-temperature 0.7)
(defvar ellama-transient-context-length 4096)
(defvar ellama-transient-host "localhost")
(defvar ellama-transient-port 11434)

(defun ellama-transient-system-show ()
  "Show transient system message."
  (format "System message (%s)"
          (string-limit (car (string-lines ellama-global-system))
                        ellama-transient-system-show-limit)))

(transient-define-suffix ellama-transient-set-system ()
  "Set system message.
If a region is active, use the text within the region as the system message.
Otherwise, prompt the user to enter a system message."
  (interactive)
  (if (region-active-p)
      (setq ellama-global-system (buffer-substring-no-properties
                                  (region-beginning) (region-end)))
    (let* ((msg-string (read-string "Set system mesage: "))
           (msg (when (not (string-empty-p msg-string)) msg-string)))
      (setq ellama-global-system msg))))

(defun ellama-transient-set-system-from-buffer ()
  "Set system message from current buffer."
  (interactive)
  (setq ellama-global-system (buffer-substring-no-properties
			      (point-min) (point-max))))

(transient-define-suffix ellama-transient-set-ollama-model ()
  "Set ollama model name."
  (interactive)
  (setq ellama-transient-ollama-model-name (ellama-get-ollama-model-name)))

(transient-define-suffix ellama-transient-set-temperature ()
  "Set temperature value."
  (interactive)
  (setq ellama-transient-temperature (read-number "Enter temperature: ")))

(transient-define-suffix ellama-transient-set-context-length ()
  "Set context length."
  (interactive)
  (setq ellama-transient-context-length (read-number "Enter context length: ")))

(transient-define-suffix ellama-transient-set-host ()
  "Set host address."
  (interactive)
  (setq ellama-transient-host (read-string "Enter host: ")))

(transient-define-suffix ellama-transient-set-port ()
  "Set port number."
  (interactive)
  (setq ellama-transient-port (read-number "Enter port: ")))

(defvar ellama-provider-list '(ellama-provider
			       ellama-coding-provider
			       ellama-translation-provider
			       ellama-extraction-provider
			       ellama-summarization-provider
			       ellama-naming-provider)
  "List of ollama providers.")

(transient-define-suffix ellama-transient-model-get-from-provider ()
  "Fill transient model from provider."
  (interactive)
  (ellama-fill-transient-ollama-model
   (eval (read
	  (completing-read "Select provider: "
			   (mapcar #'prin1-to-string ellama-provider-list))))))

(transient-define-suffix ellama-transient-model-get-from-current-session ()
  "Fill transient model from current session."
  (interactive)
  (when ellama--current-session-id
    (ellama-fill-transient-ollama-model
     (with-current-buffer (ellama-get-session-buffer ellama--current-session-id)
       (ellama-session-provider ellama--current-session)))))

(transient-define-suffix ellama-transient-set-provider ()
  "Set transient model to provider."
  (interactive)
  (let ((provider (read
		   (completing-read "Select provider: "
				    (mapcar #'prin1-to-string ellama-provider-list)))))
    (set provider
	 (ellama-construct-ollama-provider-from-transient))
    ;; if you change `ellama-provider' you probably want to start new chat session
    (when (equal provider 'ellama-provider)
      (setq ellama--current-session-id nil))))

;;;###autoload (autoload 'ellama-select-ollama-model "ellama-transient" nil t)
(transient-define-prefix ellama-select-ollama-model ()
  "Select ollama model."
  [["Model"
    ("f" "Load from provider" ellama-transient-model-get-from-provider
     :transient t)
    ("F" "Load from current session" ellama-transient-model-get-from-current-session
     :description (lambda () (format "Load from current session (%s)" ellama--current-session-id))
     :transient t)
    ("m" "Set Model" ellama-transient-set-ollama-model
     :transient t
     :description (lambda () (format "Model (%s)" ellama-transient-ollama-model-name)))
    ("t" "Set Temperature" ellama-transient-set-temperature
     :transient t
     :description (lambda () (format "Temperature (%.2f)" ellama-transient-temperature)))
    ("c" "Set Context Length" ellama-transient-set-context-length
     :transient t
     :description (lambda () (format "Context Length (%d)" ellama-transient-context-length)))
    ("S" "Set provider" ellama-transient-set-provider
     :transient t)
    ("s" "Set provider and quit" ellama-transient-set-provider)]
   ["Connection"
    ("h" "Set Host" ellama-transient-set-host
     :transient t
     :description (lambda () (if ellama-transient-host
				 (format "Host (%s)" ellama-transient-host)
			       "Host")))
    ("p" "Set Port" ellama-transient-set-port
     :transient t
     :description (lambda () (if ellama-transient-port
				 (format "Port (%s)" ellama-transient-port)
			       "Port")))]
   ["Quit" ("q" "Quit" transient-quit-one)]])

(defun ellama-fill-transient-ollama-model (provider)
  "Set transient ollama model from PROVIDER."
  (declare-function llm-ollama-p "ext:llm-ollama")
  (declare-function llm-ollama-host "ext:llm-ollama")
  (declare-function llm-ollama-port "ext:llm-ollama")
  (declare-function llm-ollama-chat-model "ext:llm-ollama")
  (declare-function llm-ollama-default-chat-temperature "ext:llm-ollama")
  (declare-function llm-ollama-default-chat-non-standard-params "ext:llm-ollama")
  (when (llm-ollama-p provider)
    (setq ellama-transient-ollama-model-name (llm-ollama-chat-model provider))
    (setq ellama-transient-temperature (or (llm-ollama-default-chat-temperature provider) 0.7))
    (setq ellama-transient-host (llm-ollama-host provider))
    (setq ellama-transient-port (llm-ollama-port provider))
    (let* ((other-params (llm-ollama-default-chat-non-standard-params provider))
	   (ctx-len (when other-params (alist-get
					"num_ctx"
					(seq--into-list other-params)
					nil nil #'string=))))
      (setq ellama-transient-context-length (or ctx-len 4096)))))

(defun ellama-construct-ollama-provider-from-transient ()
  "Make provider with ollama mode in transient menu."
  (declare-function make-llm-ollama "ext:llm-ollama")
  (require 'llm-ollama)
  (make-llm-ollama
   :chat-model ellama-transient-ollama-model-name
   :default-chat-temperature ellama-transient-temperature
   :host ellama-transient-host
   :port ellama-transient-port
   :default-chat-non-standard-params
   `[("num_ctx" . ,ellama-transient-context-length)]))

(transient-define-suffix ellama-transient-code-review (&optional args)
  "Review the code.  ARGS used for transient arguments."
  (interactive (list (transient-args transient-current-command)))
  (ellama-code-review
   (transient-arg-value "--new-session" args)
   :ephemeral (transient-arg-value "--ephemeral" args)))

;;;###autoload (autoload 'ellama-transient-code-menu "ellama-transient" nil t)
(transient-define-prefix ellama-transient-code-menu ()
  "Code Commands."
  ["Session Options"
   :description (lambda () (ellama-session-line))
   ("-n" "Create New Session" "--new-session")]
  ["Ephemeral sessions"
   :if (lambda () ellama-session-auto-save)
   ("-e" "Create Ephemeral Session" "--ephemeral")]
  [["Code Commands"
    ("c" "Complete" ellama-code-complete)
    ("a" "Add" ellama-code-add)
    ("e" "Edit" ellama-code-edit)
    ("i" "Improve" ellama-code-improve)
    ("r" "Review" ellama-transient-code-review)
    ("m" "Generate Commit Message" ellama-generate-commit-message)]
   ["Quit" ("q" "Quit" transient-quit-one)]])

;;;###autoload (autoload 'ellama-transient-summarize-menu "ellama-transient" nil t)
(transient-define-prefix ellama-transient-summarize-menu ()
  "Summarize Commands."
  [["Summarize Commands"
    ("s" "Summarize" ellama-summarize)
    ("w" "Summarize Webpage" ellama-summarize-webpage)
    ("k" "Summarize Killring" ellama-summarize-killring)]
   ["Quit" ("q" "Quit" transient-quit-one)]])

;;;###autoload (autoload 'ellama-transient-session-menu "ellama-transient" nil t)
(transient-define-prefix ellama-transient-session-menu ()
  "Session Commands."
  [["Session Commands"
    ("l" "Load Session" ellama-load-session)
    ("r" "Rename Session" ellama-session-rename)
    ("d" "Delete Session" ellama-session-delete)
    ("a" "Activate Session" ellama-session-switch)
    ("k" "Kill Session" ellama-session-kill)]
   ["Quit" ("q" "Quit" transient-quit-one)]])

;;;###autoload (autoload 'ellama-transient-improve-menu "ellama-transient" nil t)
(transient-define-prefix ellama-transient-improve-menu ()
  "Improve Commands."
  [["Improve Commands"
    ("w" "Improve Wording" ellama-improve-wording)
    ("g" "Improve Grammar" ellama-improve-grammar)
    ("c" "Improve Conciseness" ellama-improve-conciseness)]
   ["Quit" ("q" "Quit" transient-quit-one)]])

;;;###autoload (autoload 'ellama-transient-make-menu "ellama-transient" nil t)
(transient-define-prefix ellama-transient-make-menu ()
  "Make Commands."
  [["Make Commands"
    ("l" "Make List" ellama-make-list)
    ("t" "Make Table" ellama-make-table)
    ("f" "Make Format" ellama-make-format)]
   ["Quit" ("q" "Quit" transient-quit-one)]])

(transient-define-suffix ellama-transient-ask-line (&optional args)
  "Ask line.  ARGS used for transient arguments."
  (interactive (list (transient-args transient-current-command)))
  (ellama-ask-line
   (transient-arg-value "--new-session" args)
   :ephemeral (transient-arg-value "--ephemeral" args)))

(transient-define-suffix ellama-transient-ask-selection (&optional args)
  "Ask selection.  ARGS used for transient arguments."
  (interactive (list (transient-args transient-current-command)))
  (ellama-ask-selection
   (transient-arg-value "--new-session" args)
   :ephemeral (transient-arg-value "--ephemeral" args)))

(transient-define-suffix ellama-transient-ask-about (&optional args)
  "Ask about current buffer or region.  ARGS used for transient arguments."
  (interactive (list (transient-args transient-current-command)))
  (ellama-ask-about
   (transient-arg-value "--new-session" args)
   :ephemeral (transient-arg-value "--ephemeral" args)))

;;;###autoload (autoload 'ellama-transient-ask-menu "ellama-transient" nil t)
(transient-define-prefix ellama-transient-ask-menu ()
  "Ask Commands."
  ["Session Options"
   :description (lambda () (ellama-session-line))
   ("-n" "Create New Session" "--new-session")]
  ["Ephemeral sessions"
   :if (lambda () ellama-session-auto-save)
   ("-e" "Create Ephemeral Session" "--ephemeral")]
  [["Ask Commands"
    ("l" "Ask Line" ellama-transient-ask-line)
    ("s" "Ask Selection" ellama-transient-ask-selection)
    ("a" "Ask About" ellama-transient-ask-about)]
   ["Quit" ("q" "Quit" transient-quit-one)]])

;;;###autoload (autoload 'ellama-transient-translate-menu "ellama-transient" nil t)
(transient-define-prefix ellama-transient-translate-menu ()
  "Translate Commands."
  [["Translate Commands"
    ("t" "Translate Text" ellama-translate)
    ("b" "Translate Buffer" ellama-translate-buffer)
    ("e" "Enable Translation" ellama-chat-translation-enable)
    ("d" "Disable Translation" ellama-chat-translation-disable)]
   ["Quit" ("q" "Quit" transient-quit-one)]])

(declare-function ellama-context-update-buffer "ellama-context")
(defvar ellama-context-buffer)

(transient-define-suffix ellama-transient-add-buffer (&optional args)
  "Add current buffer to context.
ARGS used for transient arguments."
  (interactive (list (transient-args transient-current-command)))
  (ellama-context-add-buffer
   (read-buffer "Buffer: ")
   (transient-arg-value "--ephemeral" args)))

(transient-define-suffix ellama-transient-add-directory (&optional args)
  "Add directory to context.
ARGS used for transient arguments."
  (interactive (list (transient-args transient-current-command)))
  (let ((directory (read-directory-name "Directory: ")))
    (ellama-context-add-directory
     directory
     (transient-arg-value "--ephemeral" args))))

(transient-define-suffix ellama-transient-add-file (&optional args)
  "Add file to context.
ARGS used for transient arguments."
  (interactive (list (transient-args transient-current-command)))
  (ellama-context-add-file (transient-arg-value "--ephemeral" args)))

(transient-define-suffix ellama-transient-add-selection (&optional args)
  "Add current selection to context.
ARGS used for transient arguments."
  (interactive (list (transient-args transient-current-command)))
  (when (region-active-p)
    (ellama-context-add-selection (transient-arg-value "--ephemeral" args))))

(transient-define-suffix ellama-transient-add-info-node (&optional args)
  "Add Info Node to context.
ARGS used for transient arguments."
  (interactive (list (transient-args transient-current-command)))
  (let ((info-node (Info-copy-current-node-name)))
    (ellama-context-add-info-node
     info-node
     (transient-arg-value "--ephemeral" args))))

;;;###autoload (autoload 'ellama-transient-context-menu "ellama-transient" nil t)
(transient-define-prefix ellama-transient-context-menu ()
  "Context Commands."
  ["Options"
   ("-e" "Use Ephemeral Context" "--ephemeral")]
  ["Context Commands"
   :description (lambda ()
		  (ellama-context-update-buffer)
		  (format "Current context:
%s" (with-current-buffer ellama-context-buffer
      (buffer-substring (point-min) (point-max)))))
   ["Add"
    ("b" "Add Buffer" ellama-transient-add-buffer)
    ("d" "Add Directory" ellama-transient-add-directory)
    ("f" "Add File" ellama-transient-add-file)
    ("s" "Add Selection" ellama-transient-add-selection)
    ("i" "Add Info Node" ellama-transient-add-info-node)]
   ["Manage"
    ("m" "Manage context" ellama-context-manage)
    ("D" "Delete element" ellama-context-element-remove-by-name)
    ("r" "Context reset" ellama-context-reset)]
   ["Quit" ("q" "Quit" transient-quit-one)]])

;;;###autoload (autoload 'ellama-transient-blueprint-menu "ellama-transient" nil t)
(transient-define-prefix ellama-transient-blueprint-menu ()
  "Blueprint Menu."
  ["Blueprint Commands"
   ["Chat"
    ("b" "Blueprint" ellama-blueprint-select)
    ("U" "User defined blueprint" ellama-blueprint-select-user-defined-blueprint)
    ("C" "Community blueprint" ellama-community-prompts-select-blueprint)]
   ["Create"
    ("c" "Create from buffer" ellama-blueprint-create)
    ("n" "New blueprint" ellama-blueprint-new)]
   ["Quit" ("q" "Quit" transient-quit-one)]])

;;;###autoload (autoload 'ellama-transient-blueprint-mode-menu "ellama-transient" nil t)
(transient-define-prefix ellama-transient-blueprint-mode-menu ()
  ["Blueprint Commands"
   ["Chat"
    ("c" "Send to chat" ellama-send-buffer-to-new-chat-then-kill)]
   ["System Message"
    ("s" "Set system and chat" ellama-blueprint-chat-with-system-kill-buffer)
    ("S" "Set system and quit" ellama-blueprint-set-system-kill-buffer)]
   ["Create"
    ("C" "Create new blueprint from buffer" ellama-blueprint-create)]
   ["Variables"
    ("v" "Fill variables" ellama-blueprint-fill-variables)]
   ["Quit"
    ("k" "Kill" ellama-kill-current-buffer)
    ("q" "Quit" transient-quit-one)]])

(transient-define-suffix ellama-transient-chat (&optional args)
  "Chat with Ellama.  ARGS used for transient arguments."
  (interactive (list (transient-args transient-current-command)))
  (ellama-chat
   (read-string "Ask Ellama: ")
   (transient-arg-value "--new-session" args)
   :ephemeral (transient-arg-value "--ephemeral" args)))

;;;###autoload (autoload 'ellama-transient-main-menu "ellama-transient" nil t)
(transient-define-prefix ellama-transient-main-menu ()
  "Main Menu."
  ["Session Options"
   :description (lambda () (ellama-session-line))
   ("-n" "Create New Session" "--new-session")]
  ["Ephemeral sessions"
   :if (lambda () ellama-session-auto-save)
   ("-e" "Create Ephemeral Session" "--ephemeral")]
  ["Main"
   [("ce" "Chat" ellama-transient-chat)
    ("cj" "Custom Chat" ellama-custom-chat-from-current-buffer)
    ("cc""Custom Chat Clear" ellama-custom-chat-from-current-buffer-clear)
    ("j" "Chat Custom" ellama-custom-chat)
    ("J" "Chat Custom Select Provider" ellama-custom-chat-select-provider)
    ("b" "Chat with blueprint" ellama-blueprint-select)
    ("B" "Blueprint Commands" ellama-transient-blueprint-menu)]
   [("a" "Ask Commands" ellama-transient-ask-menu)
    ("C" "Code Commands" ellama-transient-code-menu)]]
  ["Text"
   [("w" "Write" ellama-write)
    ("P" "Proofread" ellama-proofread)
    ("k" "Text Complete" ellama-complete)
    ("g" "Text change" ellama-change)
    ("d" "Define word" ellama-define-word)]
   [("sm" "Switch Custom Model" ellama-custom-switch-model)
    ("ss" "Summarize" ellama-transient-summarize-menu)
    ("I" "Improve Commands" ellama-transient-improve-menu)
    ("t" "Translate Commands" ellama-transient-translate-menu)
    ("m" "Make Commands" ellama-transient-make-menu)]]
  ["System"
   [("o" "Ollama model" ellama-select-ollama-model)
    ("im" "Model info" ellama-custom-model-info)
    ("ii" "Interrupt Custom Generation" ellama-custom-interrupt)
    ("l" "List models" ellama-custom-list-models)
    ("p" "Provider selection" ellama-provider-select)
    ("y" "Set system message" ellama-transient-set-system
     :transient t
     :description ellama-transient-system-show)
    ("Y" "Edit system message" ellama-blueprint-edit-system-message)]
   [("S" "Session Commands" ellama-transient-session-menu)
    ("x" "Context Commands" ellama-transient-context-menu)]]
  [["Problem solving"
    ("R" "Solve reasoning problem" ellama-solve-reasoning-problem)
    ("D" "Solve domain specific problem" ellama-solve-domain-specific-problem)]]
  [["Quit" ("q" "Quit" transient-quit-one)]]
  (interactive)
  (transient-setup 'ellama-transient-main-menu)
  (when (and ellama-use-ollama-p (string-empty-p ellama-transient-ollama-model-name))
    (ellama-fill-transient-ollama-model ellama-provider)))

;;;###autoload (autoload 'ellama "ellama-transient" nil t)
(defalias 'ellama 'ellama-transient-main-menu)

(provide 'ellama-transient)
;;; ellama-transient.el ends here.
