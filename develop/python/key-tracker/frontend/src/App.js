import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import { Container, Nav, Navbar } from 'react-bootstrap';
import { useTranslation } from 'react-i18next';

import SitesList from './components/SitesList';
import SiteForm from './components/SiteForm';
import KeysList from './components/KeysList';
import KeyForm from './components/KeyForm';
import IssueKeyForm from './components/IssueKeyForm';
import ReturnKeyForm from './components/ReturnKeyForm';
import ActiveKeys from './components/ActiveKeys';
import KeyHistory from './components/KeyHistory';
import Dashboard from './components/Dashboard';
import BackupRestore from './components/BackupRestore';
import LanguageSwitcher from './components/LanguageSwitcher';

import 'bootstrap/dist/css/bootstrap.min.css';
import './App.css';

function App() {
  const { t } = useTranslation();
  
  return (
    <Router>
      <div className="App">
        <Navbar bg="dark" variant="dark" expand="lg">
          <Container>
            <Navbar.Brand as={Link} to="/">{t('app.title')}</Navbar.Brand>
            <Navbar.Toggle aria-controls="basic-navbar-nav" />
            <Navbar.Collapse id="basic-navbar-nav">
              <Nav className="me-auto">
                <Nav.Link as={Link} to="/">{t('menu.home')}</Nav.Link>
                <Nav.Link as={Link} to="/sites">{t('menu.sites')}</Nav.Link>
                <Nav.Link as={Link} to="/keys">{t('menu.keys')}</Nav.Link>
                <Nav.Link as={Link} to="/active">{t('menu.issuedKeys')}</Nav.Link>
                <Nav.Link as={Link} to="/history">{t('menu.history')}</Nav.Link>
                <Nav.Link as={Link} to="/backup">{t('menu.backup')}</Nav.Link>
              </Nav>
              <Nav>
                <LanguageSwitcher />
              </Nav>
            </Navbar.Collapse>
          </Container>
        </Navbar>
        
        <Container className="mt-4 mb-4">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/sites" element={<SitesList />} />
            <Route path="/sites/add" element={<SiteForm />} />
            <Route path="/sites/edit/:siteCode" element={<SiteForm />} />
            <Route path="/keys" element={<KeysList />} />
            <Route path="/keys/add" element={<KeyForm />} />
            <Route path="/keys/edit/:keyId" element={<KeyForm />} />
            <Route path="/keys/issue" element={<IssueKeyForm />} />
            <Route path="/keys/return" element={<ReturnKeyForm />} />
            <Route path="/active" element={<ActiveKeys />} />
            <Route path="/history" element={<KeyHistory />} />
            <Route path="/backup" element={<BackupRestore />} />
          </Routes>
        </Container>
        
        <footer className="bg-dark text-light text-center py-3 mt-auto">
          <Container>
            <p>{t('app.footer')}</p>
          </Container>
        </footer>
      </div>
    </Router>
  );
}

export default App;

