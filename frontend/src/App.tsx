import { Routes, Route, Navigate } from "react-router-dom";
import Home from "./pages/Home";
import Vault from "./pages/Vault";

export default function App() {
    return (
        <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/vault" element={<Vault />} />
            <Route path="*" element={<Navigate to="/" />} />
        </Routes>
    );
}
