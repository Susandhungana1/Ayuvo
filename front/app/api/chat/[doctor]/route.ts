import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = 'http://127.0.0.1:3001';

export async function GET(request: NextRequest, { params }: { params: { doctor: string } }) {
  const authHeader = request.headers.get('authorization');
  
  if (!authHeader) {
    return NextResponse.json({ error: 'No authorization header' }, { status: 401 });
  }
  
  const response = await fetch(`${BACKEND_URL}/api/chat/${params.doctor}`, {
    headers: { 'Authorization': authHeader },
  });
  
  const data = await response.json();
  return NextResponse.json(data);
}

export async function POST(request: NextRequest, { params }: { params: { doctor: string } }) {
  const authHeader = request.headers.get('authorization');
  const body = await request.json();
  
  if (!authHeader) {
    return NextResponse.json({ error: 'No authorization header' }, { status: 401 });
  }
  
  const response = await fetch(`${BACKEND_URL}/api/chat/${params.doctor}`, {
    method: 'POST',
    headers: {
      'Authorization': authHeader,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  
  const data = await response.json();
  return NextResponse.json(data);
}