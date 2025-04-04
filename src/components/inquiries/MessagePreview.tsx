import React from 'react';
import { X, Send } from 'lucide-react';
import { FileList } from '../files/FileList';

interface MessagePreviewProps {
  message: string;
  attachedFiles: Array<{
    id: string;
    name: string;
    size: number;
    type: string;
    label?: string;
  }>;
  onClose: () => void;
  onSend: (e: React.FormEvent) => void;
}

export function MessagePreview({ message, attachedFiles, onClose, onSend }: MessagePreviewProps) {
  return (
    <div className="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-6 max-w-2xl w-full mx-4">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-lg font-medium text-gray-900">Preview Message</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-500"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="space-y-4">
          <div className="bg-gray-50 rounded-lg p-4">
            <h3 className="text-sm font-medium text-gray-700 mb-2">Message</h3>
            <div className="whitespace-pre-wrap text-sm text-gray-900">
              {message}
            </div>
          </div>

          {attachedFiles.length > 0 && (
            <div>
              <h3 className="text-sm font-medium text-gray-700 mb-2">Attachments</h3>
              <FileList files={attachedFiles} />
            </div>
          )}

          <div className="flex justify-end space-x-3 mt-6">
            <button
              onClick={onClose}
              className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            >
              Edit
            </button>
            <button
              onClick={onSend}
              className="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-green-600 border border-transparent rounded-md hover:bg-green-700"
            >
              <Send className="h-4 w-4 mr-2" />
              Send Message
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}