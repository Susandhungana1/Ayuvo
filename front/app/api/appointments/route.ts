import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = (process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001');

export async function GET(request: NextRequest) {
  const authHeader = request.headers.get('authorization');
  
  if (!authHeader) {
    return NextResponse.json({ error: 'No authorization header' }, { status: 401 });
  }
  
  const response = await fetch(`${BACKEND_URL}/api/appointments`, {
    headers: { 'Authorization': authHeader },
  });
  
  const data = await response.json();
  return NextResponse.json(data);
}

export async function POST(request: NextRequest) {
  const authHeader = request.headers.get('authorization');
  const body = await request.json();
  
  if (!authHeader) {
    return NextResponse.json({ error: 'No authorization header' }, { status: 401 });
  }
  
  const response = await fetch(`${BACKEND_URL}/api/appointments`, {
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

export async function DELETE(request: NextRequest) {
  const authHeader = request.headers.get('authorization');
  const { searchParams } = new URL(request.url);
  const id = searchParams.get('id');
  
  if (!authHeader || !id) {
    return NextResponse.json({ error: 'Missing parameters' }, { status: 400 });
  }
  
  const response = await fetch(`${BACKEND_URL}/api/appointments/${id}`, {
    method: 'DELETE',
    headers: { 'Authorization': authHeader },
  });
  
  const data = await response.json();
  return NextResponse.json(data);
}