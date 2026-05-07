import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = 'http://127.0.0.1:3001';

export async function GET(request: NextRequest) {
  const authHeader = request.headers.get('authorization');
  
  if (!authHeader) {
    return NextResponse.json({ error: 'No authorization header' }, { status: 401 });
  }
  
  const response = await fetch(`${BACKEND_URL}/api/reports`, {
    headers: { 'Authorization': authHeader },
  });
  
  const data = await response.json();
  return NextResponse.json(data);
}

export async function POST(request: NextRequest) {
  const authHeader = request.headers.get('authorization');
  
  if (!authHeader) {
    return NextResponse.json({ error: 'No authorization header' }, { status: 401 });
  }
  
  const formData = await request.formData();
  const file = formData.get('file');
  
  const backendFormData = new FormData();
  if (file) {
    backendFormData.append('file', file);
  }
  
  // Add other fields directly (not as JSON)
  formData.forEach((value, key) => {
    if (key !== 'file' && typeof value === 'string') {
      backendFormData.append(key, value);
    }
  });
  
  const response = await fetch(`${BACKEND_URL}/api/reports`, {
    method: 'POST',
    headers: { 'Authorization': authHeader },
    body: backendFormData,
  });
  
  const data = await response.json();
  return NextResponse.json(data, { status: response.status });
}