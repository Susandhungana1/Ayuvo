import { Shield, Users, Heart } from 'lucide-react';

export default function About() {
  return (
    <div className="bg-background min-h-screen py-16">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        
        {/* Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <h1 className="text-4xl md:text-5xl font-extrabold text-text-main mb-6">About MediStore</h1>
          <p className="text-lg text-subtext leading-relaxed">
            MediStore is your personal digital health store — a secure platform to store medical records, track vital signs, manage medications, book appointments, generate reports, and share your health data with doctors — all in one place.
          </p>
        </div>

        {/* What We Do */}
        <div className="mb-24">
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-8 md:p-12 flex flex-col md:flex-row gap-12 items-center">
            <div className="flex-1">
              <h2 className="text-3xl font-bold text-text-main mb-6">What We Do</h2>
              <p className="text-subtext mb-4 leading-relaxed">
                MediStore lets you upload and organize lab results, prescriptions, and medical history, track vital signs like blood pressure, heart rate, blood sugar, and weight, manage your medications with dose reminders, book appointments with doctors, generate AI-powered medical reports, and share records securely via encrypted links.
              </p>
            </div>
            <div className="flex-1 w-full bg-blue-50 rounded-xl p-8 flex items-center justify-center min-h-[300px]">
              {/* Abstract Illustration/Graphic Placeholder */}
              <div className="grid grid-cols-2 gap-4 w-full max-w-sm">
                <div className="bg-white rounded-xl h-32 shadow-sm"></div>
                <div className="bg-blue-200 rounded-xl h-24 mt-8 opacity-50"></div>
                <div className="bg-green-100 rounded-xl h-24 -mt-4 opacity-50"></div>
                <div className="bg-white rounded-xl h-32 shadow-sm"></div>
              </div>
            </div>
          </div>
        </div>

        {/* Why Choose Us */}
        <div>
          <h2 className="text-3xl font-bold text-text-main text-center mb-12">Why Choose Us</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="bg-white rounded-xl p-8 shadow-sm border border-gray-100 text-center">
              <div className="w-16 h-16 bg-blue-100 text-primary rounded-full flex items-center justify-center mx-auto mb-6">
                <Shield size={32} />
              </div>
              <h3 className="text-xl font-bold text-text-main mb-3">Vitals & Medicines</h3>
              <p className="text-subtext">Track blood pressure, heart rate, blood sugar, and more. Manage your medications with intelligent dose reminders.</p>
            </div>

            <div className="bg-white rounded-xl p-8 shadow-sm border border-gray-100 text-center">
              <div className="w-16 h-16 bg-green-100 text-secondary rounded-full flex items-center justify-center mx-auto mb-6">
                <Users size={32} />
              </div>
              <h3 className="text-xl font-bold text-text-main mb-3">Reports & Appointments</h3>
              <p className="text-subtext">Generate detailed medical reports and book appointments with doctors directly through the platform.</p>
            </div>

            <div className="bg-white rounded-xl p-8 shadow-sm border border-gray-100 text-center">
              <div className="w-16 h-16 bg-blue-100 text-primary rounded-full flex items-center justify-center mx-auto mb-6">
                <Heart size={32} />
              </div>
              <h3 className="text-xl font-bold text-text-main mb-3">Secure & Private</h3>
              <p className="text-subtext">Your data is encrypted end-to-end. Share records securely via encrypted links — only you control access.</p>
            </div>
          </div>
        </div>
        
      </div>
    </div>
  );
}
