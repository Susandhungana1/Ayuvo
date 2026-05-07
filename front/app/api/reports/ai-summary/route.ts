import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = 'http://127.0.0.1:3001';

export async function GET(request: NextRequest) {
  const authHeader = request.headers.get('authorization');
  
  if (!authHeader) {
    return NextResponse.json({ error: 'No authorization header' }, { status: 401 });
  }
  
  const response = await fetch(`${BACKEND_URL}/api/reports/ai-summary`, {
    headers: { 'Authorization': authHeader },
  });
  
  const data = await response.json();
  return NextResponse.json(data);
}