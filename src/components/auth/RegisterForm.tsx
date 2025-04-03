import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import { Mail, Lock, AlertCircle, Building2, Warehouse } from 'lucide-react';

export function RegisterForm() {
  const { signUp } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [selectedRole, setSelectedRole] = useState<'customer' | 'warehouse_owner'>('customer');
  const [acceptedTerms, setAcceptedTerms] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    if (password !== confirmPassword) {
      setError('Passwords do not match');
      setIsLoading(false);
      return;
    }

    try {
      const { error, needsEmailVerification } = await signUp(email, password, selectedRole);
      
      if (error) throw error;
      
      if (needsEmailVerification) {
        setSuccess('Please check your email for a verification link.');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="w-full max-w-md space-y-8">
      <div>
        <h2 className="text-center text-3xl font-bold tracking-tight text-gray-900">
          Create your account
        </h2>
      </div>

      <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
        {success && (
          <div className="bg-green-50 border border-green-200 text-green-700 px-4 py-3 rounded relative">
            {success}
          </div>
        )}
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded relative" role="alert">
            <div className="flex">
              <AlertCircle className="h-5 w-5 mr-2" />
              <span className="block sm:inline">{error}</span>
            </div>
          </div>
        )}

        {/* Role Selection */}
        <div className="mt-6">
          <label className="block text-sm font-medium text-gray-700 mb-4">
            I want to:
          </label>
          <div className="grid grid-cols-2 gap-4">
            <button
              type="button"
              onClick={() => setSelectedRole('customer')}
              className={`flex flex-col items-center p-4 border-2 rounded-lg transition-colors ${
                selectedRole === 'customer'
                  ? 'border-green-500 bg-green-50'
                  : 'border-gray-200 hover:border-green-300'
              }`}
            >
              <Building2 className="h-8 w-8 mb-2 text-gray-600" />
              <span className="text-sm font-medium">Book a Warehouse</span>
            </button>
            
            <button
              type="button"
              onClick={() => setSelectedRole('warehouse_owner')}
              className={`flex flex-col items-center p-4 border-2 rounded-lg transition-colors ${
                selectedRole === 'warehouse_owner'
                  ? 'border-green-500 bg-green-50'
                  : 'border-gray-200 hover:border-green-300'
              }`}
            >
              <Warehouse className="h-8 w-8 mb-2 text-gray-600" />
              <span className="text-sm font-medium">List a Warehouse</span>
            </button>
          </div>
        </div>

        <div className="space-y-4 rounded-md shadow-sm">
          <div>
            <label htmlFor="email" className="sr-only">Email address</label>
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <Mail className="h-5 w-5 text-gray-400" />
              </div>
              <input
                id="email"
                name="email"
                type="email"
                autoComplete="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="block w-full pl-10 border-gray-300 rounded-md focus:ring-green-500 focus:border-green-500"
                placeholder="Email address"
              />
            </div>
          </div>

          <div>
            <label htmlFor="password" className="sr-only">Password</label>
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <Lock className="h-5 w-5 text-gray-400" />
              </div>
              <input
                id="password"
                name="password"
                type="password"
                autoComplete="new-password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="block w-full pl-10 border-gray-300 rounded-md focus:ring-green-500 focus:border-green-500"
                placeholder="Password"
              />
            </div>
          </div>

          <div>
            <label htmlFor="confirmPassword" className="sr-only">Confirm Password</label>
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <Lock className="h-5 w-5 text-gray-400" />
              </div>
              <input
                id="confirmPassword"
                name="confirmPassword"
                type="password"
                autoComplete="new-password"
                required
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                className="block w-full pl-10 border-gray-300 rounded-md focus:ring-green-500 focus:border-green-500"
                placeholder="Confirm password"
              />
            </div>
          </div>
        </div>

        <div className="text-sm text-gray-600">
          <p>Password must be at least 8 characters long</p>
        </div>

        <div className="mt-4">
          <label className="flex items-start">
            <input
              type="checkbox"
              checked={acceptedTerms}
              onChange={(e) => setAcceptedTerms(e.target.checked)}
              className="mt-1 rounded border-gray-300 text-green-600 shadow-sm focus:border-green-500 focus:ring-green-500"
            />
            <span className="ml-2 text-sm text-gray-500">
              I accept the{' '}
              <Link to="/terms" className="text-green-600 hover:text-green-700" target="_blank">
                Terms & Conditions
              </Link>
              {' '}and{' '}
              <Link to="/privacy" className="text-green-600 hover:text-green-700" target="_blank">
                Privacy Policy
              </Link>
            </span>
          </label>
        </div>

        <button
          type="submit"
          disabled={isLoading || !acceptedTerms || !email || !password || !confirmPassword}
          className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 disabled:opacity-50"
        >
          {isLoading ? 'Creating account...' : 'Create account'}
        </button>
      </form>
    </div>
  );
}