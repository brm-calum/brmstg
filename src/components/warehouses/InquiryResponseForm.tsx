import React, { useState } from 'react';
import { MessageSquare } from 'lucide-react';

interface InquiryResponseFormProps {
  inquiryId: string;
  onSubmit: (response: string) => Promise<void>;
  onCancel: () => void;
}

export function InquiryResponseForm({ inquiryId, onSubmit, onCancel }: InquiryResponseFormProps) {
  const [response, setResponse] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    try {
      await onSubmit(response);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to send response');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded relative">
          {error}
        </div>
      )}

      <div>
        <label className="block text-sm font-medium text-gray-700">
          Your Response
        </label>
        <div className="mt-1 relative">
          <div className="absolute top-3 left-3">
            <MessageSquare className="h-5 w-5 text-gray-400" />
          </div>
          <textarea
            required
            value={response}
            onChange={(e) => setResponse(e.target.value)}
            rows={4}
            className="block w-full pl-10 border-gray-300 rounded-md focus:ring-green-500 focus:border-green-500"
            placeholder="Type your response..."
          />
        </div>
      </div>

      <div className="flex justify-end space-x-3">
        <button
          type="button"
          onClick={onCancel}
          className="px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
        >
          Cancel
        </button>
        <button
          type="submit"
          disabled={isLoading}
          className="px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700 disabled:opacity-50"
        >
          {isLoading ? 'Sending...' : 'Send Response'}
        </button>
      </div>
    </form>
  );
}