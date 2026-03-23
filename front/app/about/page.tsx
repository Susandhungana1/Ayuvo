import { Shield, Users, Heart } from 'lucide-react';

export default function About() {
  return (
    <div className="bg-background min-h-screen py-16">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        
        {/* Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <h1 className="text-4xl md:text-5xl font-extrabold text-text-main mb-6">About HealthTracker</h1>
          <p className="text-lg text-subtext leading-relaxed">
            Our mission is to empower individuals to take control of their medical records. 
            We believe that managing your health should be simple, secure, and accessible from anywhere.
          </p>
        </div>

        {/* What We Do */}
        <div className="mb-24">
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-8 md:p-12 flex flex-col md:flex-row gap-12 items-center">
            <div className="flex-1">
              <h2 className="text-3xl font-bold text-text-main mb-6">What We Do</h2>
              <p className="text-subtext mb-4 leading-relaxed">
                HealthTracker provides a centralized, digital vault for all your personal healthcare information. 
                Instead of scattered physical documents and multiple patient portals, we give you one secure place to store, track, and share your medical history.
              </p>
              <p className="text-subtext leading-relaxed">
                Whether you're managing a chronic condition, keeping track of family vaccinations, or just trying to stay organized, our platform gives you the tools you need to stay on top of your well-being.
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
              <h3 className="text-xl font-bold text-text-main mb-3">Bank-Level Security</h3>
              <p className="text-subtext">Your data is encrypted end-to-end. Only you decide who gets access to your medical records.</p>
            </div>

            <div className="bg-white rounded-xl p-8 shadow-sm border border-gray-100 text-center">
              <div className="w-16 h-16 bg-green-100 text-secondary rounded-full flex items-center justify-center mx-auto mb-6">
                <Users size={32} />
              </div>
              <h3 className="text-xl font-bold text-text-main mb-3">Easy Sharing</h3>
              <p className="text-subtext">Instantly share relevant documents with new specialists or family members with a single click.</p>
            </div>

            <div className="bg-white rounded-xl p-8 shadow-sm border border-gray-100 text-center">
              <div className="w-16 h-16 bg-blue-100 text-primary rounded-full flex items-center justify-center mx-auto mb-6">
                <Heart size={32} />
              </div>
              <h3 className="text-xl font-bold text-text-main mb-3">Patient First</h3>
              <p className="text-subtext">Designed with patients in mind, ensuring an intuitive, frustration-free experience for users of all ages.</p>
            </div>
          </div>
        </div>
        
      </div>
    </div>
  );
}
