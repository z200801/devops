import React, { useState, useEffect } from 'react';
import { Container, Table, Button, Alert, Form, InputGroup } from 'react-bootstrap';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import axios from 'axios';

const API_URL = '/api';

const KeysList = () => {
  const { t } = useTranslation();
  const [keys, setKeys] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [filterValue, setFilterValue] = useState('');
  const [isRegExp, setIsRegExp] = useState(false);
  
  useEffect(() => {
    fetchKeys();
  }, []);
  
  const fetchKeys = async () => {
    try {
      setLoading(true);
      const response = await axios.get(`${API_URL}/keys/`);
      setKeys(response.data);
      setError(null);
    } catch (err) {
      console.error('Error fetching keys:', err);
      setError(t('keys.errorFetching'));
    } finally {
      setLoading(false);
    }
  };
  
  const handleDelete = async (keyId) => {
    if (window.confirm(t('keys.confirmDelete', {keyId}))) {
      try {
        await axios.delete(`${API_URL}/keys/${keyId}`);
        // Оновити список після видалення
        fetchKeys();
      } catch (err) {
        console.error('Error deleting key:', err);
        setError(t('keys.errorDeleting'));
      }
    }
  };
  
  const handleFilterChange = (e) => {
    setFilterValue(e.target.value);
  };
  
  const toggleRegExp = () => {
    setIsRegExp(!isRegExp);
  };
  
  // Функція фільтрації даних
  const getFilteredKeys = () => {
    if (!filterValue.trim()) return keys;
    
    try {
      if (isRegExp) {
        const regex = new RegExp(filterValue, 'i');
        return keys.filter(key => 
          regex.test(key.site_code) || 
          regex.test(key.description) ||
          regex.test(key.memo || '')
        );
      } else {
        const lowercaseFilter = filterValue.toLowerCase();
        return keys.filter(key => 
          key.site_code.toLowerCase().includes(lowercaseFilter) || 
          key.description.toLowerCase().includes(lowercaseFilter) ||
          (key.memo && key.memo.toLowerCase().includes(lowercaseFilter))
        );
      }
    } catch (err) {
      console.error('Error filtering keys:', err);
      return keys;
    }
  };
  
  const filteredKeys = getFilteredKeys();
  
  return (
    <Container>
      <div className="d-flex justify-content-between align-items-center mb-4">
        <h1>{t('keys.title')}</h1>
        <Link to="/keys/add">
          <Button variant="primary">{t('keys.addKey')}</Button>
        </Link>
      </div>
      
      <Form.Group className="mb-3">
        <InputGroup>
          <Form.Control
            type="text"
            placeholder={t('keys.filter')}
            value={filterValue}
            onChange={handleFilterChange}
          />
          <InputGroup.Checkbox 
            label="RegExp"
            checked={isRegExp}
            onChange={toggleRegExp}
          />
          <InputGroup.Text>RegExp</InputGroup.Text>
        </InputGroup>
        <Form.Text className="text-muted">
          {isRegExp ? t('keys.filterMode.regexp') : t('keys.filterMode.simple')}
        </Form.Text>
      </Form.Group>
      
      {error && <Alert variant="danger">{error}</Alert>}
      
      {loading ? (
        <p>{t('keys.loading')}</p>
      ) : filteredKeys.length === 0 ? (
        <Alert variant="info">{t('keys.noKeys')}</Alert>
      ) : (
        <Table striped bordered hover responsive>
          <thead>
            <tr>
              <th>{t('keys.columns.id')}</th>
              <th>{t('keys.columns.site')}</th>
              <th>{t('keys.columns.description')}</th>
              <th>{t('keys.columns.keyCount')}</th>
              <th>{t('keys.columns.setCount')}</th>
              <th>{t('keys.columns.status')}</th>
              <th>{t('keys.columns.notes')}</th>
              <th>{t('keys.columns.actions')}</th>
            </tr>
          </thead>
          <tbody>
            {filteredKeys.map((key) => (
              <tr key={key.key_id}>
                <td>{key.key_id}</td>
                <td>{key.site_code}</td>
                <td>{key.description}</td>
                <td>{key.key_count}</td>
                <td>{key.set_count}</td>
                <td>
                  <span className={key.is_issued ? "text-danger" : "text-success"}>
                    {key.is_issued ? t('keys.status.issued') : t('keys.status.available')}
                  </span>
                </td>
                <td>{key.memo || '-'}</td>
                <td>
                  <div className="d-flex">
                    <Link to={`/keys/edit/${key.key_id}`} className="btn btn-sm btn-warning me-2">
                      {t('keys.actions.edit')}
                    </Link>
                    <Button 
                      variant="danger" 
                      size="sm" 
                      onClick={() => handleDelete(key.key_id)}
                    >
                      {t('keys.actions.delete')}
                    </Button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
    </Container>
  );
};

export default KeysList;

