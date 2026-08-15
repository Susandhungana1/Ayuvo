'use client';

import { useState, useRef, useEffect, useSyncExternalStore } from 'react';
import { Lock, MessageCircle, Mic, MicOff, Send, X } from 'lucide-react';
import { useSpeechRecognition } from '@/lib/useSpeechRecognition';
import { getSessionServerSnapshot, getSessionSnapshot, subscribeSession } from '@/lib/session';
import { Button } from '@/components/ui/button';

const API_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

interface Message {
  role: 'user' | 'assistant';
  content: string;
}

export function ChatBot() {
  const [open, setOpen] = useState(false);
  const [messages, setMessages] = useState<Message[]>([
    { role: 'assistant', content: 'Hi! I\'m your health assistant. Ask me anything about health, diseases, medicines, nutrition, or wellness.' }
  ]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);
  const { listening, supported, toggle } = useSpeechRecognition(
    (text) => setInput((prev) => (prev ? prev + ' ' : '') + text)
  );

  // Session read from localStorage; reacts to login/logout via the shared
  // session store (storage + localStorageUpdated events).
  const session = useSyncExternalStore(
    subscribeSession,
    getSessionSnapshot,
    getSessionServerSnapshot,
  );
  const isLoggedIn = !!session.token;

  // Close the panel when the user logs out. Deferred so the setState happens
  // after the render that observed the login change.
  useEffect(() => {
    if (isLoggedIn) return;
    const id = setTimeout(() => setOpen(false), 0);
    return () => clearTimeout(id);
  }, [isLoggedIn]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const handleSend = async () => {
    const text = input.trim();
    if (!text || loading) return;
    setInput('');

    const userMsg: Message = { role: 'user', content: text };
    const updated = [...messages, userMsg];
    setMessages(updated);
    setLoading(true);

    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/chatbot`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { 'Authorization': `Bearer ${token}` } : {})
        },
        body: JSON.stringify({
          messages: updated.map(m => ({ role: m.role, content: m.content }))
        })
      });

      if (res.ok) {
        const data = await res.json();
        setMessages(prev => [...prev, { role: 'assistant', content: data.reply }]);
      } else {
        const err = await res.json();
        setMessages(prev => [...prev, { role: 'assistant', content: `Error: ${err.detail || 'Failed to get response'}` }]);
      }
    } catch {
      setMessages(prev => [...prev, { role: 'assistant', content: 'Network error. Please try again.' }]);
    } finally {
      setLoading(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <>
      <button
        onClick={() => setOpen(!open)}
        className="fixed bottom-6 right-6 z-50 w-14 h-14 bg-primary hover:bg-primary-pressed text-on-primary rounded-full shadow-float flex items-center justify-center transition-colors duration-fast"
        aria-label="Toggle health assistant"
      >
        {open ? <X className="w-6 h-6" /> : <MessageCircle className="w-6 h-6" />}
      </button>

      {open && !isLoggedIn && (
        <div className="fixed bottom-24 right-4 sm:right-6 z-50 w-[calc(100vw-2rem)] sm:w-96 max-w-96 bg-surface-card rounded-lg shadow-pop border border-outline flex flex-col overflow-hidden anim-pop-in">
          <div className="bg-primary text-on-primary px-4 py-3 flex items-center gap-2">
            <div className="w-2 h-2 bg-ok rounded-full animate-pulse" />
            <span className="font-semibold text-sm font-display">Health Assistant</span>
          </div>
          <div className="p-6 text-center">
            <div className="mx-auto mb-3 w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
              <Lock className="w-6 h-6 text-primary" />
            </div>
            <p className="text-sm font-semibold text-on-surface mb-1">Please log in to use the chatbot</p>
            <p className="text-xs text-on-surface-variant mb-4">The health assistant is available for logged-in users.</p>
            <a
              href="/auth/login"
              className="inline-block bg-primary hover:bg-primary-pressed text-on-primary text-sm font-medium rounded-sm px-5 py-2 transition-colors"
            >
              Log in
            </a>
          </div>
        </div>
      )}

      {open && isLoggedIn && (
        <div className="fixed bottom-24 right-4 sm:right-6 z-50 w-[calc(100vw-2rem)] sm:w-96 max-w-96 h-[500px] max-h-[calc(100vh-8rem)] bg-surface-card rounded-lg shadow-pop border border-outline flex flex-col overflow-hidden anim-pop-in">
          <div className="bg-primary text-on-primary px-4 py-3 flex items-center gap-2">
            <div className="w-2 h-2 bg-ok rounded-full animate-pulse" />
            <span className="font-semibold text-sm font-display">Health Assistant</span>
          </div>

          <div className="flex-1 overflow-y-auto p-3 space-y-3 bg-surface">
            {messages.map((msg, i) => (
              <div key={i} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
                <div
                  className={`max-w-[85%] rounded-md px-4 py-2.5 text-sm leading-relaxed ${
                    msg.role === 'user'
                      ? 'bg-primary text-on-primary rounded-br-xs'
                      : 'bg-surface-card text-on-surface rounded-bl-xs border border-outline'
                  }`}
                >
                  {msg.content}
                </div>
              </div>
            ))}
            {loading && (
              <div className="flex justify-start">
                <div className="bg-surface-card rounded-md rounded-bl-xs px-4 py-2.5 border border-outline">
                  <div className="flex gap-1">
                    <div className="w-2 h-2 bg-on-surface-variant rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
                    <div className="w-2 h-2 bg-on-surface-variant rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
                    <div className="w-2 h-2 bg-on-surface-variant rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
                  </div>
                </div>
              </div>
            )}
            <div ref={bottomRef} />
          </div>

          <div className="border-t border-outline p-3 bg-surface-card">
            <div className="flex gap-2">
              <input
                value={input}
                onChange={e => setInput(e.target.value)}
                onKeyDown={handleKeyDown}
                placeholder={listening ? 'Listening…' : 'Ask about health...'}
                className="flex-1 rounded-sm border border-outline bg-surface px-3 py-2 text-sm text-on-surface placeholder:text-on-surface-variant/70 outline-none focus:ring-2 focus:ring-focus-ring focus:border-transparent"
                disabled={loading}
              />
              {supported && (
                <button
                  onClick={toggle}
                  title={listening ? 'Stop voice input' : 'Speak your question'}
                  aria-label="Voice input"
                  className={`rounded-sm px-3 py-2 transition-colors ${listening ? 'bg-alert text-white animate-pulse' : 'bg-surface text-on-surface-variant hover:bg-primary/5'}`}
                >
                  {listening ? <MicOff className="w-5 h-5" /> : <Mic className="w-5 h-5" />}
                </button>
              )}
              <Button
                onClick={handleSend}
                disabled={!input.trim() || loading}
                aria-label="Send message"
              >
                <Send className="w-5 h-5" />
              </Button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}