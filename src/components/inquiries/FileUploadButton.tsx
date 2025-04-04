import React, { useRef } from 'react';
import { Paperclip } from 'lucide-react';

interface FileUploadButtonProps {
  onFileSelect: (files: FileList) => void;
  disabled?: boolean;
  maxSize?: number;
  accept?: string;
  className?: string;
}

export function FileUploadButton({ 
  onFileSelect, 
  disabled = false,
  maxSize = 10 * 1024 * 1024, // 10MB default
  accept = "image/*,application/pdf,.doc,.docx",
  className = ""
}: FileUploadButtonProps) {
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleClick = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files?.length) return;

    // Validate file size
    const invalidFiles = Array.from(files).filter(file => file.size > maxSize);
    if (invalidFiles.length > 0) {
      alert(`Some files exceed the ${maxSize / 1024 / 1024}MB size limit`);
      return;
    }

    onFileSelect(files);
    
    // Reset input to allow selecting the same file again
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  return (
    <>
      <button
        type="button"
        onClick={handleClick}
        disabled={disabled}
        className={`inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 disabled:opacity-50 ${className}`}
      >
        <Paperclip className="h-4 w-4 mr-2" />
        Attach File
      </button>
      <input
        ref={fileInputRef}
        type="file"
        className="hidden"
        onChange={handleFileChange}
        accept={accept}
        multiple
      />
    </>
  );
}