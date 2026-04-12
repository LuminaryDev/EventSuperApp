import { db } from '@/db';
import { sql } from 'drizzle-orm';
import { NextResponse } from 'next/server';

export async function GET() {
  console.log('DATABASE_URL_WEB:', process.env.DATABASE_URL_WEB ? 'defined' : 'UNDEFINED');
  try {
    const result = await db.execute(sql`SELECT NOW()`);
    return NextResponse.json({ status: 'ok', time: result[0].now });
  } catch (error) {
    console.error(error);
    return NextResponse.json({ status: 'error', message: String(error) }, { status: 500 });
  }
}