// admin/src/pages/Users.jsx
import { useState, useEffect } from 'react';
import axios from 'axios';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000';

export default function Users() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [modalType, setModalType] = useState('add'); // 'add' or 'edit' or 'reset'
  const [selectedUser, setSelectedUser] = useState(null);
  const [formData, setFormData] = useState({
    email: '',
    first_name: '',
    last_name: '',
    phone_number: '',
    password: '',
    role: 'donor',
  });
  const [resetPassword, setResetPassword] = useState('');

  useEffect(() => {
    loadUsers();
  }, []);

  const loadUsers = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await axios.get(`${API_URL}/api/admin/users`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setUsers(response.data.data || []);
    } catch (error) {
      console.error('Error loading users:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleAddUser = () => {
    setModalType('add');
    setFormData({
      email: '',
      first_name: '',
      last_name: '',
      phone_number: '',
      password: '',
      role: 'donor',
    });
    setShowModal(true);
  };

  const handleEditUser = (user) => {
    setModalType('edit');
    setSelectedUser(user);
    setFormData({
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      phone_number: user.phone_number,
      role: user.role,
      password: '',
    });
    setShowModal(true);
  };

  const handleResetPassword = (user) => {
    setModalType('reset');
    setSelectedUser(user);
    setResetPassword('');
    setShowModal(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const token = localStorage.getItem('token');

    try {
      if (modalType === 'add') {
        await axios.post(`${API_URL}/api/auth/register`, formData, {
          headers: { Authorization: `Bearer ${token}` }
        });
        alert('User added successfully!');
      } else if (modalType === 'edit') {
        await axios.put(`${API_URL}/api/admin/users/${selectedUser.user_id}`, formData, {
          headers: { Authorization: `Bearer ${token}` }
        });
        alert('User updated successfully!');
      } else if (modalType === 'reset') {
        await axios.post(`${API_URL}/api/admin/users/${selectedUser.user_id}/reset-password`, 
          { password: resetPassword },
          { headers: { Authorization: `Bearer ${token}` }
        });
        alert('Password reset successfully!');
      }
      setShowModal(false);
      loadUsers();
    } catch (error) {
      alert(error.response?.data?.message || 'Operation failed');
    }
  };

  const handleDeleteUser = async (userId) => {
    if (!confirm('Are you sure you want to delete this user?')) return;

    try {
      const token = localStorage.getItem('token');
      await axios.delete(`${API_URL}/api/admin/users/${userId}`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      alert('User deleted successfully!');
      loadUsers();
    } catch (error) {
      alert(error.response?.data?.message || 'Delete failed');
    }
  };

  if (loading) return <div className="flex items-center justify-center h-96">Loading...</div>;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-800">User Management</h1>
          <p className="text-gray-600 mt-1">Manage users, admins, and permissions</p>
        </div>
        <button onClick={handleAddUser} className="btn btn-primary">
          + Add New User
        </button>
      </div>

      {/* Users Table */}
      <div className="bg-white rounded-xl shadow-md">
        <table className="w-full">
          <thead className="bg-gray-50 border-b">
            <tr>
              <th className="px-6 py-3 text-left text-sm font-semibold text-gray-700">Name</th>
              <th className="px-6 py-3 text-left text-sm font-semibold text-gray-700">Email</th>
              <th className="px-6 py-3 text-left text-sm font-semibold text-gray-700">Phone</th>
              <th className="px-6 py-3 text-left text-sm font-semibold text-gray-700">Role</th>
              <th className="px-6 py-3 text-left text-sm font-semibold text-gray-700">Actions</th>
            </tr>
          </thead>
          <tbody>
            {users.map((user) => (
              <tr key={user.user_id} className="border-b hover:bg-gray-50">
                <td className="px-6 py-4">{user.first_name} {user.last_name}</td>
                <td className="px-6 py-4">{user.email}</td>
                <td className="px-6 py-4">{user.phone_number}</td>
                <td className="px-6 py-4">
                  <span className={`px-3 py-1 rounded-full text-sm ${
                    user.role === 'admin' ? 'bg-purple-100 text-purple-700' :
                    user.role === 'staff' ? 'bg-blue-100 text-blue-700' :
                    'bg-gray-100 text-gray-700'
                  }`}>
                    {user.role}
                  </span>
                </td>
                <td className="px-6 py-4">
                  <div className="flex space-x-2">
                    <button onClick={() => handleEditUser(user)} className="text-blue-600 hover:underline text-sm">
                      Edit
                    </button>
                    <button onClick={() => handleResetPassword(user)} className="text-yellow-600 hover:underline text-sm">
                      Reset Password
                    </button>
                    <button onClick={() => handleDeleteUser(user.user_id)} className="text-red-600 hover:underline text-sm">
                      Delete
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl p-8 max-w-md w-full">
            <h2 className="text-2xl font-bold mb-4">
              {modalType === 'add' ? 'Add New User' :
               modalType === 'edit' ? 'Edit User' :
               'Reset Password'}
            </h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              {modalType !== 'reset' && (
                <>
                  <input
                    type="email"
                    placeholder="Email"
                    value={formData.email}
                    onChange={(e) => setFormData({...formData, email: e.target.value})}
                    className="input"
                    required
                  />
                  <input
                    type="text"
                    placeholder="First Name"
                    value={formData.first_name}
                    onChange={(e) => setFormData({...formData, first_name: e.target.value})}
                    className="input"
                    required
                  />
                  <input
                    type="text"
                    placeholder="Last Name"
                    value={formData.last_name}
                    onChange={(e) => setFormData({...formData, last_name: e.target.value})}
                    className="input"
                    required
                  />
                  <input
                    type="text"
                    placeholder="Phone Number"
                    value={formData.phone_number}
                    onChange={(e) => setFormData({...formData, phone_number: e.target.value})}
                    className="input"
                  />
                  <select
                    value={formData.role}
                    onChange={(e) => setFormData({...formData, role: e.target.value})}
                    className="input"
                    required
                  >
                    <option value="donor">Donor</option>
                    <option value="admin">Admin</option>
                    <option value="staff">Staff</option>
                    <option value="finance">Finance</option>
                  </select>
                  {modalType === 'add' && (
                    <input
                      type="password"
                      placeholder="Password"
                      value={formData.password}
                      onChange={(e) => setFormData({...formData, password: e.target.value})}
                      className="input"
                      required
                    />
                  )}
                </>
              )}
              {modalType === 'reset' && (
                <input
                  type="password"
                  placeholder="New Password"
                  value={resetPassword}
                  onChange={(e) => setResetPassword(e.target.value)}
                  className="input"
                  required
                  minLength={8}
                />
              )}
              <div className="flex space-x-4">
                <button type="submit" className="btn btn-primary flex-1">
                  {modalType === 'add' ? 'Add User' :
                   modalType === 'edit' ? 'Update User' :
                   'Reset Password'}
                </button>
                <button type="button" onClick={() => setShowModal(false)} className="btn bg-gray-300 flex-1">
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}