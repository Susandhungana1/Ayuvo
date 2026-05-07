'use client';

import { useEffect, useState, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/button';
import { Card } from '@/components/card';
import { Input } from '@/components/input';

const API_URL = 'http://127.0.0.1:3001';

const toNepalTime = (utcDate: string) => {
  const date = new Date(utcDate);
  date.setHours(date.getHours() + 5);
  date.setMinutes(date.getMinutes() + 45);
  return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true });
};

interface Doctor {
  id: string;
  nmid: string;
  name: string;
  degree: string;
  specialty: string;
}

interface Message {
  sender: string;
  content: string;
  timestamp: string;
}

export default function Chat() {
  const router = useRouter();
  const [doctors, setDoctors] = useState<Doctor[]>([]);
  const [selectedDoctor, setSelectedDoctor] = useState<Doctor | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [userId, setUserId] = useState<string>('');
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const token = localStorage.getItem('token');
    const userData = localStorage.getItem('user');
    if (!token || !userData) {
      router.push('/auth/login');
      return;
    }
    const parsed = JSON.parse(userData);
    setUserId(parsed.id || parsed.email);
    fetchDoctors();
  }, [router]);

  useEffect(() => {
    if (selectedDoctor) {
      fetchMessages();
    }
  }, [selectedDoctor]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const fetchDoctors = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/doctors/doctors`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setDoctors(data.doctors || data || []);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const fetchMessages = async () => {
    if (!selectedDoctor) return;
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/chat/${selectedDoctor.id}`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        setMessages(data.messages || []);
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMessage.trim() || !selectedDoctor) return;

    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/chat/${selectedDoctor.id}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ message: newMessage })
      });

      if (res.ok) {
        const data = await res.json();
        setMessages([...messages, data]);
        setNewMessage('');
      }
    } catch (err) {
      console.error(err);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <p className="text-subtext">Loading...</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold text-text-main">Chat with Doctor</h1>
        </div>

        {doctors.length === 0 ? (
          <Card className="p-8 text-center">
            <p className="text-subtext mb-4">No doctors available</p>
            <p className="text-subtext text-sm">Please check back later</p>
          </Card>
        ) : !selectedDoctor ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {doctors.map((doc) => (
              <Card
                key={doc.id}
                className="p-6 cursor-pointer hover:shadow-md transition-shadow"
                onClick={() => setSelectedDoctor(doc)}
              >
                <h3 className="text-lg font-semibold text-text-main mb-2">Dr. {doc.name}</h3>
                <p className="text-subtext text-sm mb-1">{doc.specialty}</p>
                <p className="text-subtext text-sm">NMID: {doc.nmid}</p>
              </Card>
            ))}
          </div>
        ) : (
          <div className="flex flex-col h-[calc(100vh-220px)] md:h-[calc(100vh-200px)]">
            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between mb-4 gap-2">
              <button
                onClick={() => setSelectedDoctor(null)}
                className="text-primary hover:text-blue-700 font-medium"
              >
                ← Back
              </button>
              <h2 className="text-lg md:text-xl font-semibold text-text-main">
                Dr. {selectedDoctor.name} - {selectedDoctor.specialty}
              </h2>
            </div>

            <Card className="flex-1 overflow-y-auto mb-4">
              <div className="p-4 space-y-4">
                {messages.length === 0 ? (
                  <p className="text-subtext text-center">No messages yet</p>
                ) : (
                  messages.map((msg, i) => (
                    <div
                      key={i}
                      className={`flex ${msg.sender === userId ? 'justify-end' : 'justify-start'}`}
                    >
                      <div
                        className={`max-w-[80%] md:max-w-md px-4 py-2 rounded-lg ${
                          msg.sender_id === userId
                            ? 'bg-primary text-white'
                            : 'bg-gray-100 text-text-main'
                        }`}
                      >
                        <p className="text-sm">{msg.message}</p>
                        <p className={`text-xs mt-1 ${
                          msg.sender_id === userId ? 'text-blue-200' : 'text-gray-500'
                        }`}>
                          {toNepalTime(msg.created_at)}
                        </p>
                      </div>
                    </div>
                  ))
                )}
                <div ref={messagesEndRef} />
              </div>
            </Card>

            <form onSubmit={handleSend} className="flex gap-2">
              <Input
                value={newMessage}
                onChange={(e) => setNewMessage(e.target.value)}
                placeholder="Type your message..."
                className="flex-1"
              />
              <Button type="submit">Send</Button>
            </form>
          </div>
        )}
      </div>
    </div>
  );
}