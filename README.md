# 🚀 Smarty AI – Smart Chat Assistant

Smarty AI is a modern AI-powered chat application built using Flutter.  
It provides intelligent conversations, real-time messaging, and a clean, interactive user experience.

---

## ✨ Features

- 🤖 AI-powered chat responses
- 💬 Real-time messaging using Firebase Firestore
- 🎨 Modern and responsive UI design
- ⌨️ Smart input field with stylish send button
- 📜 Markdown support (code blocks, formatted text)
- 🔄 Typing indicator (AI thinking animation)
- 🧹 Clear chat functionality
- 🔐 User authentication (Login/Logout)
- ⚡ State management using BLoC (Cubit)

---

## 🛠️ Tech Stack

- **Frontend:** Flutter
- **Backend:** Firebase Firestore
- **Authentication:** Firebase Auth
- **State Management:** BLoC (Cubit)
- **AI Integration:** API-based AI response system

---

## ⚙️ How It Works

1. User enters a message in the chat input.
2. The message is sent using BLoC state management.
3. API processes the request and generates AI response.
4. Both user message and AI response are stored in Firebase Firestore.
5. UI updates in real-time with latest messages.
6. Typing indicator shows while AI is responding.

---

## 📂 Project Structure


lib/
│
├── Cubit/ # State management (BLoC)
├── controller/ # Services (Auth, API)
├── view/ # UI Screens
├── widgets/ # Reusable UI components
└── main.dart # Entry point


---

## 🔐 Firebase Setup

1. Create a Firebase project
2. Enable:
   - Firestore Database
   - Authentication (Email/Password)
3. Add `google-services.json` (Android)
4. Configure Firebase in Flutter

---

## ▶️ Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/kishan-ghulekar/smarty-ai.git
2. Navigate to project
cd smarty-ai
3. Install dependencies
flutter pub get
4. Run the app
flutter run
🎯 Use Cases
AI Chat Assistant
Coding help & learning
Daily productivity queries
General conversation
🚧 Future Improvements
🌐 Multi-language support
🎙️ Voice input/output
📊 Chat history analytics
🧠 Improved AI responses
📱 Dark/Light theme toggle
🤝 Contributing

Contributions are welcome!
Feel free to fork this repo and submit a pull request.

📄 License

This project is licensed under the MIT License.

👨‍💻 Author

Kishan Ghulekar
Flutter Developer 🚀

⭐ Support

If you like this project, please ⭐ star the repository!


---

# 🚀 How to Push to GitHub (Step-by-step)

Run this in your project folder:

```bash
git init
git add .
git commit -m "Initial commit - Smarty AI app"
git branch -M main
git remote add origin https://github.com/your-username/smarty-ai.git
git push -u origin main