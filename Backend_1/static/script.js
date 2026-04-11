document.addEventListener('DOMContentLoaded', () => {
    // --- Elements ---
    // PDF Upload
    const pdfInput = document.getElementById('pdfInput');
    const uploadBtn = document.getElementById('uploadBtn');
    const uploadText = document.querySelector('.upload-text');
    const uploadStatus = document.getElementById('uploadStatus');
    const pdfDropZone = document.getElementById('pdfDropZone');

    // Chat
    const chatForm = document.getElementById('chatForm');
    const messageInput = document.getElementById('messageInput');
    const sendBtn = document.getElementById('sendBtn');
    const chatMessages = document.getElementById('chatMessages');

    // Image Input
    const imageInput = document.getElementById('imageInput');
    const imagePreviewContainer = document.getElementById('imagePreviewContainer');
    const imagePreview = document.getElementById('imagePreview');
    const removeImageBtn = document.getElementById('removeImageBtn');

    // State
    let selectedPdf = null;
    let selectedImage = null;

    // --- PDF Upload Logic ---
    const handlePdfSelection = (file) => {
        if (!file) return;
        selectedPdf = file;
        uploadText.textContent = selectedPdf.name;
        uploadBtn.disabled = false;
    };

    pdfInput.addEventListener('change', (e) => {
        if (e.target.files.length > 0) {
            handlePdfSelection(e.target.files[0]);
        }
    });

    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        pdfDropZone.addEventListener(eventName, (e) => {
            e.preventDefault();
            e.stopPropagation();
        }, false);
    });

    ['dragenter', 'dragover'].forEach(eventName => {
        pdfDropZone.addEventListener(eventName, () => {
            pdfDropZone.classList.add('dragover');
        }, false);
    });

    ['dragleave', 'drop'].forEach(eventName => {
        pdfDropZone.addEventListener(eventName, () => {
            pdfDropZone.classList.remove('dragover');
        }, false);
    });

    pdfDropZone.addEventListener('drop', (e) => {
        const files = e.dataTransfer.files;
        if (files.length > 0) {
            pdfInput.files = files;
            handlePdfSelection(files[0]);
            // Instruct standard click behavior!
            uploadBtn.click();
        }
    });

    uploadBtn.addEventListener('click', async () => {
        if (!selectedPdf) return;

        uploadBtn.disabled = true;
        uploadStatus.className = 'status-msg loading';
        uploadStatus.textContent = 'Processing document... (This encrypts & vectorizes)';
        
        const formData = new FormData();
        formData.append('file', selectedPdf);

        try {
            const res = await fetch('/api/upload', {
                method: 'POST',
                body: formData
            });

            if (res.ok) {
                uploadStatus.className = 'status-msg success';
                uploadStatus.innerHTML = '<i class="fa-solid fa-check"></i> Document processed successfully!';
                // Reset file internal state so multiple can be processed sequentially if needed
                setTimeout(() => {
                    uploadStatus.textContent = '';
                    uploadText.textContent = 'Browse or drop PDF';
                    selectedPdf = null;
                    pdfInput.value = '';
                }, 4000);
            } else {
                const data = await res.json();
                throw new Error(data.detail || 'Upload failed');
            }
        } catch (error) {
            uploadStatus.className = 'status-msg error';
            uploadStatus.textContent = error.message;
            uploadBtn.disabled = false;
        }
    });

    // --- Image Preview Logic ---
    imageInput.addEventListener('change', (e) => {
        if (e.target.files.length > 0) {
            selectedImage = e.target.files[0];
            const reader = new FileReader();
            reader.onload = (e) => {
                imagePreview.src = e.target.result;
                imagePreviewContainer.classList.remove('hidden');
            };
            reader.readAsDataURL(selectedImage);
            checkChatSubmitStatus();
        }
    });

    removeImageBtn.addEventListener('click', () => {
        selectedImage = null;
        imageInput.value = '';
        imagePreviewContainer.classList.add('hidden');
        imagePreview.removeAttribute('src');
        checkChatSubmitStatus();
    });

    // --- Chat Logic ---
    messageInput.addEventListener('input', () => {
        // Auto-resize textarea
        messageInput.style.height = 'auto';
        messageInput.style.height = (messageInput.scrollHeight) + 'px';
        checkChatSubmitStatus();
    });

    messageInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            if (!sendBtn.disabled) {
                chatForm.dispatchEvent(new Event('submit'));
            }
        }
    });

    function checkChatSubmitStatus() {
        sendBtn.disabled = !(messageInput.value.trim() !== '' || selectedImage !== null);
    }

    function appendMessage(role, content, isHtml = false, imgSrc = null) {
        const msgDiv = document.createElement('div');
        msgDiv.className = `message ${role}`;
        
        const avatarDiv = document.createElement('div');
        avatarDiv.className = 'avatar';
        // Icons are strictly hardcoded static strings, safe for innerHTML
        avatarDiv.innerHTML = role === 'assistant' ? '<i class="fa-solid fa-stethoscope"></i>' : '<i class="fa-solid fa-user"></i>';
        
        const msgContentDiv = document.createElement('div');
        msgContentDiv.className = 'msg-content';
        
        if (imgSrc) {
            const imgEl = document.createElement('img');
            imgEl.src = imgSrc;
            imgEl.className = 'msg-img-preview';
            msgContentDiv.appendChild(imgEl);
        }
        
        if (isHtml) {
            // Sanitize via DOMPurify before parsing Markdown -> HTML to prevent AI/RAG XSS
            msgContentDiv.innerHTML = DOMPurify.sanitize(content);
        } else {
            // User payloads use textContent to strictly block payload execution!
            const textEl = document.createElement('p');
            textEl.textContent = content;
            msgContentDiv.appendChild(textEl);
        }
        
        msgDiv.appendChild(avatarDiv);
        msgDiv.appendChild(msgContentDiv);
        
        chatMessages.appendChild(msgDiv);
        chatMessages.scrollTop = chatMessages.scrollHeight;
        return msgDiv;
    }

    function showTypingIndicator() {
        const msgDiv = document.createElement('div');
        msgDiv.className = `message assistant typing-msg`;
        msgDiv.innerHTML = `
            <div class="avatar"><i class="fa-solid fa-stethoscope"></i></div>
            <div class="msg-content">
                <div class="typing-indicator">
                    <div class="typing-dot"></div>
                    <div class="typing-dot"></div>
                    <div class="typing-dot"></div>
                </div>
            </div>
        `;
        chatMessages.appendChild(msgDiv);
        chatMessages.scrollTop = chatMessages.scrollHeight;
        return msgDiv;
    }

    chatForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        
        const textMessage = messageInput.value.trim();
        const msgImage = selectedImage;
        const msgImageSrc = imagePreview.src;
        
        if (!textMessage && !msgImage) return;

        // UI Reset
        messageInput.value = '';
        messageInput.style.height = 'auto';
        if (msgImage) {
            removeImageBtn.click(); // resets selection state
        }
        checkChatSubmitStatus();

        // Append user message securely!
        const userText = textMessage || '[Image Attachment]';
        appendMessage('user', userText, false, msgImage ? msgImageSrc : null);

        // Append loader
        const loader = showTypingIndicator();

        // Prepare request
        const formData = new FormData();
        formData.append('message', textMessage || "Please analyze this image.");
        if (msgImage) {
            formData.append('image', msgImage);
        }

        try {
            const res = await fetch('/api/chat', {
                method: 'POST',
                body: formData
            });

            loader.remove(); // Remove loader

            if (res.ok) {
                const data = await res.json();
                // Parse markdown securely!
                const parsedHtml = marked.parse(data.response);
                appendMessage('assistant', parsedHtml, true);
            } else {
                appendMessage('assistant', 'Sorry, the diagnostic server encountered an error parsing this query.', false);
            }
        } catch (error) {
            loader.remove();
            appendMessage('assistant', 'Network error. Please ensure the backend is running.', false);
        }
    });
});
