#!/usr/bin/env python3
import http.server
import socketserver
import os
import webbrowser
import threading
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()

class LiveHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=SCRIPT_DIR, **kwargs)
    
    def end_headers(self):
        # Add CORS headers and disable caching for live reload
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()
    
    def do_GET(self):
        # Handle check-changes endpoint
        if self.path == '/check-changes':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            changed = checker.check_files()
            self.wfile.write(b'{"changed": ' + (b'true' if changed else b'false') + b'}')
            return
        
        # Auto-redirect to index.html if root is requested
        if self.path == '/':
            self.path = '/index.html'
        
        # Add live reload script to HTML files
        if self.path.endswith('.html'):
            try:
                file_path = self.translate_path(self.path)
                if os.path.exists(file_path):
                    with open(file_path, 'rb') as f:
                        content = f.read()
                    # Inject live reload script for index.html
                    if self.path == '/index.html':
                        content = content.replace(b'</body>', self.get_live_reload_script() + b'</body>')
                    self.send_response(200)
                    self.send_header('Content-type', 'text/html')
                    self.end_headers()
                    self.wfile.write(content)
                else:
                    self.send_error(404, "File not found")
            except Exception as e:
                self.send_error(404, f"File not found: {e}")
        else:
            super().do_GET()
    
    def get_live_reload_script(self):
        return b'''
        <script>
        let lastModified = {};
        function checkForChanges() {
            fetch('/check-changes')
                .then(response => response.json())
                .then(data => {
                    if (data.changed) {
                        console.log('Files changed, reloading...');
                        location.reload();
                    }
                })
                .catch(() => {});
        }
        setInterval(checkForChanges, 1000);
        </script>
        '''

class ChangeChecker:
    def __init__(self):
        self.last_modified = {}
        self.check_files()
    
    def check_files(self):
        current_files = {}
        changed = False
        
        for root, dirs, files in os.walk(SCRIPT_DIR):
            # Skip hidden directories and common build directories
            dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ['node_modules', '__pycache__', 'dist', 'build']]
            
            for file in files:
                if file.endswith(('.html', '.css', '.js', '.json', '.md')):
                    file_path = os.path.join(root, file)
                    try:
                        mtime = os.path.getmtime(file_path)
                        current_files[file_path] = mtime
                        
                        if file_path in self.last_modified and self.last_modified[file_path] != mtime:
                            changed = True
                    except OSError:
                        pass
        
        self.last_modified = current_files
        return changed

def start_server(port=3000):
    global checker
    checker = ChangeChecker()
    
    handler = LiveHTTPRequestHandler
    
    try:
        with socketserver.TCPServer(("", port), handler) as httpd:
            print(f"\\n=== Live Server Started ===")
            print(f"Server running at: http://localhost:{port}")
            print(f"Serving files from: {SCRIPT_DIR}")
            print(f"Open your browser and navigate to: http://localhost:{port}")
            print(f"Press Ctrl+C to stop the server")
            print("============================\\n")
            
            # Open browser automatically
            def open_browser():
                time.sleep(1)
                webbrowser.open(f'http://localhost:{port}')
            
            threading.Thread(target=open_browser, daemon=True).start()
            
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\\nServer stopped.")
    except OSError as e:
        # Check for address already in use: 48 (Mac/Linux) or 10048 (Windows)
        if e.errno == 48 or getattr(e, 'winerror', None) == 10048 or getattr(e, 'errno', None) == 98:
            print(f"Port {port} is already in use. Trying port {port + 1}...")
            start_server(port + 1)
        else:
            print(f"Error starting server: {e}")

if __name__ == "__main__":
    start_server()
