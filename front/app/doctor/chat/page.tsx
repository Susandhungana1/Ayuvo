'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Card } from '@/components/card';
import { Button } from '@/components/button';
import { Input } from '@/components/input';

const API_URL = 'http://127.0.0.1:3001';

const toNepalTime = (utcDate: string) => {
  if (!utcDate) return '';
  const date = new Date(utcDate);
  date.setHours(date.getHours() + 5);
  date.setMinutes(date.getMinutes() + 45);
  return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true });
};

interface Conversation {
  patient_id: string;
  patient_name: string;
  last_message: string;
  last_time: string;
  unread_count: number;
}

interface Message {
  id: string;
  sender_id: string;
  receiver_id: string;
  message: string;
  read: boolean;
  created_at: string;
}

export default function DoctorChat() {
  const router = useRouter();
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [selectedPatient, setSelectedPatient] = useState<string | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('token');
    const userData = localStorage.getItem('user');
    
    if (!token || !userData) {
      router.push('/auth/login');
      return;
    }

    const user = JSON.parse(userData);
    if (user.role !== 'DOCTOR') {
      router.push('/dashboard');
      return;
    }

    fetchConversations();
  }, [router]);

  const fetchConversations = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_URL}/api/chat/doctor/conversations`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      
      if (res.ok) {
        const data = await res.json();
        setConversations(data || []);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const fetchMessages = async (patientId: string) => {
    try {
      const token = localStorage.getItem('token');
      const user = JSON.parse(localStorage.getItem('user') || '{}');
      
      // Get all messages for current user (doctor)
      const res = await fetch(`${API_URL}/api/chat/my-messages`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      
      if (res.ok) {
        const data = await res.json();
        console.log('All messages response:', data);
        
        const allMessages = data.messages || [];
        
        // Filter messages between doctor and this patient
        const filtered = allMessages.filter((m: any) => 
          (m.sender_id === patientId && m.receiver_id === user.id) ||
          (m.sender_id === user.id && m.receiver_id === patientId)
        );
        
        console.log('Filtered messages:', filtered);
        setMessages(filtered);
      }
    } catch (err) {
      console.error(err);
    }
  };

  const handleSelectPatient = (patientId: string) => {
    setSelectedPatient(patientId);
    fetchMessages(patientId);
  };

  const handleSendMessage = async () => {
    if (!newMessage.trim() || !selectedPatient) {
      console.log('No message or no patient selected', newMessage, selectedPatient);
      return;
    }
    
    try {
      const token = localStorage.getItem('token');
      console.log('Sending to:', selectedPatient);
      
      // Encode the patient ID to handle # character
      const encodedPatient = encodeURIComponent(selectedPatient);
      const res = await fetch(`${API_URL}/api/chat/send-to-user/${encodedPatient}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({
          message: newMessage
        })
      });
      
      console.log('Response:', res.status);
      
      if (res.ok) {
        const data = await res.json();
        console.log('Message sent:', data);
        setNewMessage('');
        fetchMessages(selectedPatient);
      } else {
        const err = await res.json();
        console.error('Error:', err);
      }
    } catch (err) {
      console.error('Exception:', err);
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
          <h1 className="text-3xl font-bold text-text-main">Patient Messages</h1>
          <Button onClick={() => router.push('/dashboard')}>Back to Dashboard</Button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {/* Conversations List */}
          <div className="md:col-span-1">
            <h2 className="text-xl font-semibold text-text-main mb-4">Conversations</h2>
            {conversations.length === 0 ? (
              <Card className="p-6 text-center">
                <p className="text-subtext">No messages yet</p>
              </Card>
            ) : (
              <div className="space-y-3">
                {conversations.map((conv) => (
                  <Card 
                    key={conv.patient_id} 
                    className={`p-4 cursor-pointer hover:shadow-md transition-shadow ${
                      selectedPatient === conv.patient_id ? 'border-2 border-primary' : ''
                    }`}
                    onClick={() => handleSelectPatient(conv.patient_id)}
                  >
                    <div className="flex justify-between items-center">
                      <h3 className="font-semibold text-text-main">{conv.patient_name}</h3>
                      {conv.unread_count > 0 && (
                        <span className="bg-red-500 text-white text-xs px-2 py-1 rounded-full">
                          {conv.unread_count}
                        </span>
                      )}
                    </div>
                    <p className="text-subtext text-sm mt-1 truncate">{conv.last_message}</p>
                  </Card>
                ))}
              </div>
            )}
          </div>

          {/* Chat Area */}
          <div className="md:col-span-2">
            {selectedPatient ? (
              <div className="flex flex-col h-[600px]">
                <div className="flex-1 overflow-y-auto space-y-4 p-4 bg-white rounded-lg">
                  {messages.length === 0 ? (
                    <p className="text-subtext text-center">No messages yet</p>
                  ) : (
                    messages.map((msg) => (
                      <div 
                        key={msg.id} 
                        className={`flex ${msg.sender_id === selectedPatient ? 'justify-start' : 'justify-end'}`}
                      >
                        <div className={`max-w-[70%] p-3 rounded-lg ${
                          msg.sender_id === selectedPatient 
                            ? 'bg-gray-100 text-text-main' 
                            : 'bg-primary text-white'
                        }`}>
                          <p>{msg.message}</p>
                          <p className="text-xs mt-1 opacity-70">
                            {toNepalTime(msg.created_at)}
                          </p>
                        </div>
                      </div>
                    ))
                  )}
                </div>
                
                <div className="mt-4 flex gap-2">
                  <Input
                    value={newMessage}
                    onChange={(e) => setNewMessage(e.target.value)}
                    placeholder="Type your message..."
                    onKeyPress={(e) => e.key === 'Enter' && handleSendMessage()}
                  />
                  <Button onClick={handleSendMessage}>Send</Button>
                </div>
              </div>
            ) : (
              <Card className="p-8 text-center h-full flex items-center justify-center">
                <p className="text-subtext">Select a conversation to view messages</p>
              </Card>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}